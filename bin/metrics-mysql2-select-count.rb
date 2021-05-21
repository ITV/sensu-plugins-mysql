#!/usr/bin/env ruby
#
# MySQL Select Count Metric
#
# Creates a graphite-formatted metric for the first value of a result set from a MySQL query.
#
# Copyright 2017 Andrew Thal <athal7@me.com>
# Copyright 2018 Tibor Nagy <nagyt@hu.inter.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/metric/cli'
require 'mysql2'
require 'inifile'

class MysqlQueryCountMetric < Sensu::Plugin::Metric::CLI::Graphite
    option :host,
        short: '-h HOST',
        long: '--host HOST',
        description: 'MySQL Host to connect to',
        required: true

    option :port,
        short: '-P PORT',
        long: '--port PORT',
        description: 'MySQL Port to connect to',
        proc: proc(&:to_i),
        default: 3306

    option :username,
        short: '-u USERNAME',
        long: '--user USERNAME',
        description: 'MySQL Username'

    option :password,
        short: '-p PASSWORD',
        long: '--pass PASSWORD',
        description: 'MySQL password'

    option :database,
        short: '-d DATABASE',
        long: '--database DATABASE',
        description: 'MySQL database',
        default: ''

    option :ini,
        short: '-i',
        long: '--ini VALUE',
        description: 'My.cnf ini file'

    option :ini_section,
        description: 'Section in my.cnf ini file',
        long: '--ini-section VALUE',
        default: 'client'

    option :socket,
        short: '-S SOCKET',
        long: '--socket SOCKET',
        description: 'MySQL Unix socket to connect to'

    option :name,
        short: '-n NAME',
        long: '--name NAME',
        description: 'Metric name for a configured handler',
        default: 'mysql.query_count'

    option :query,
        short: '-q SELECT_COUNT_QUERY',
        long: '--query SELECT_COUNT_QUERY',
        description: 'Query to execute',
        required: true

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

        raise "invalid query : #{config[:query]}" unless config[:query] =~ /^select\s+count\(\s*\*\s*\)/i

        db = Mysql2::Client.new(:hostname => hostname, :username => db_user, :password => db_pass, :database => database, :port => port, :socket => socket)
        count = db.query(config[:query]).fetch_row[0].to_i
        output config[:name], count
        ok

        rescue Mysql2::Error => e
            errstr = "Error code: #{e.errno} Error message: #{e.error}"
            critical "#{errstr} SQLSTATE: #{e.sqlstate}" if e.respond_to?('sqlstate')
        rescue StandardError => e
            critical "unhandled exception: #{e}"
        ensure
            db.close if db
    end
end
