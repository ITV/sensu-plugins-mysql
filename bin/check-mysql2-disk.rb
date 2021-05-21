#!/usr/bin/env ruby
#
# MySQL Disk Usage Check
# ===
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Check the size of the database and compare to crit and warn thresholds

require 'sensu-plugin/check/cli'
require 'mysql2'
require 'inifile'

class CheckMysqlDisk < Sensu::Plugin::Check::CLI
    option :hostname,
        description: 'Hostname to login to',
        short: '-h HOST',
        long: '--hostname HOST'

    option :user,
        short: '-u',
        long: '--username=VALUE',
        description: 'Database username'

    option :password,
        short: '-p',
        long: '--password=VALUE',
        description: 'Database password'

    option :ini,
        description: 'My.cnf ini file',
        short: '-i',
        long: '--ini VALUE'

    option :ini_section,
        description: 'Section in my.cnf ini file',
        long: '--ini-section VALUE',
        default: 'client'

    option :size,
        short: '-s',
        long: '--size=VALUE',
        description: 'Database size',
        proc: proc(&:to_f),
        required: true

    option :warn,
        short: '-w',
        long: '--warning=VALUE',
        description: 'Warning threshold',
        proc: proc(&:to_f),
        default: 85

    option :crit,
        short: '-c',
        long: '--critical=VALUE',
        description: 'Critical threshold',
        proc: proc(&:to_f),
        default: 95

    option :port,
        description: 'Port to connect to',
        short: '-P PORT',
        long: '--port PORT',
        proc: proc(&:to_i),
        default: 3306

    option :socket,
        description: 'Socket to use',
        short: '-S SOCKET',
        long: '--socket SOCKET',
        default: nil

    def run
        if config[:ini]
            ini = IniFile.load(config[:ini])
            section  = ini[config[:ini_section]]
            hostname = section['hostname']
            db_user  = section['user']
            db_pass  = section['password']
            database = section['database']
            port     = section['port'].to_i
            socket   = section['socket']
        else
            hostname = config[:hostname]
            db_user  = config[:user]
            db_pass  = config[:password]
            database = config[:database]
            port     = config[:port].to_i
            socket   = config[:socket]
        end

        disk_size      = config[:size]
        critical_usage = config[:crit]
        warning_usage  = config[:warn]

        begin

            db = Mysql2::Client.new(:host => config[:hostname], :username => db_user, :password => db_pass, :database =>config[:database], :port => port, :socket => socket)

            total_size = 0.0

            results = db.query <<-SQL
                SELECT table_schema,
                count(*) TABLES,
                concat(round(sum(table_rows)/1000000,2),'M') rows,
                round(sum(data_length)/(1024*1024*1024),2) DATA,
                round(sum(index_length)/(1024*1024*1024),2) idx,
                round(sum(data_length+index_length)/(1024*1024*1024),2) total_size,
                round(sum(index_length)/sum(data_length),2) idxfrac
                FROM information_schema.TABLES group by table_schema
            SQL

            results&.each_hash do |row|
                # #YELLOW
                total_size = total_size + row['total_size'].to_f # rubocop:disable Style/SelfAssignment
              end
        
              disk_use_percentage = total_size / disk_size * 100
              diskstr = "DB size: #{total_size}, disk use: #{disk_use_percentage}%"
        
              if disk_use_percentage > critical_usage
                critical "Database size exceeds critical threshold: #{diskstr}"
              elsif disk_use_percentage > warning_usage
                warning "Database size exceeds warning threshold: #{diskstr}"
              else
                ok diskstr
              end

            rescue Mysql2::Error => e
                critical "Error message: #{e.error}"
            ensure
                db.close if db
        end
    end
end
