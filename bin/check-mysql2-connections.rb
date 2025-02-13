#!/usr/bin/env ruby
#
# MySQL Health Plugin
# ===
#
# This plugin counts the maximum connections your MySQL has reached and warns you according to specified limits
#
# Copyright 2012 Panagiotis Papadomitsos <pj@ezgr.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'mysql2'
require 'inifile'

class CheckMySQLHealth < Sensu::Plugin::Check::CLI
    option :user,
        description: 'MySQL User',
        short: '-u USER',
        long: '--user USER',
        default: 'root'

    option :password,
        description: 'MySQL Password',
        short: '-p PASS',
        long: '--password PASS'

    option :ini,
        description: 'My.cnf ini file',
        short: '-i',
        long: '--ini VALUE'

    option :ini_section,
        description: 'Section in my.cnf ini file',
        long: '--ini-section VALUE',
        default: 'client'

    option :hostname,
        description: 'Hostname to login to',
        short: '-h HOST',
        long: '--hostname HOST',
        default: 'localhost'

    option :port,
        description: 'Port to connect to',
        short: '-P PORT',
        long: '--port PORT',
        default: '3306'

    option :socket,
        description: 'Socket to use',
        short: '-s SOCKET',
        long: '--socket SOCKET'

    option :maxwarn,
        description: "Number of connections upon which we'll issue a warning",
        short: '-w NUMBER',
        long: '--warnnum NUMBER',
        default: 100

    option :maxcrit,
        description: "Number of connections upon which we'll issue an alert",
        short: '-c NUMBER',
        long: '--critnum NUMBER',
        default: 128

    option :usepc,
        description: 'Use percentage of defined max connections instead of absolute number',
        short: '-a',
        long: '--percentage',
        default: false

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
        db = Mysql2::Client.new(:host => config[:hostname], :username => db_user, :password => db_pass, :database =>config[:database], :port => config[:port].to_i, :socket => config[:socket])

        max_con = db.query("SHOW VARIABLES LIKE 'max_connections'").first.fetch('Value').to_i
        used_con = db.query("SHOW GLOBAL STATUS LIKE 'Threads_connected'").first.fetch('Value').to_i

        if config[:usepc]
            pc = used_con.fdiv(max_con) * 100
            critical "Max connections reached in MySQL: #{used_con} out of #{max_con}" if pc >= config[:maxcrit].to_i
            warning "Max connections reached in MySQL: #{used_con} out of #{max_con}" if pc >= config[:maxwarn].to_i
            ok "Max connections is under limit in MySQL: #{used_con} out of #{max_con}" # rubocop:disable Style/IdenticalConditionalBranches
        else
            critical "Max connections reached in MySQL: #{used_con} out of #{max_con}" if used_con >= config[:maxcrit].to_i
            warning "Max connections reached in MySQL: #{used_con} out of #{max_con}" if used_con >= config[:maxwarn].to_i
            ok "Max connections is under limit in MySQL: #{used_con} out of #{max_con}" # rubocop:disable Style/IdenticalConditionalBranches
        end

        rescue Mysql2::Error => e
            critical "MySQL check failed: #{e.error}"
        ensure
            db.close if db
    end
end
