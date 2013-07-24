#!/usr/bin/env ruby

=begin
Intel-DB: unstructured structure for intelligence analysis
    Copyright (C) 2012-2013 Ryan M. Victory

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see [http://www.gnu.org/licenses/].
=end

require_relative './library/ExportLibrary'
require 'optparse'
require 'mongo'
require 'parseconfig'

include Mongo
# This hash will hold all of the options
 # parsed from the command-line by
 # OptionParser.
 options = {}
 
 optparse = OptionParser.new do|opts|
   # Set a banner, displayed at the top
   # of the help screen.
   opts.banner = "Usage: intel-db-export.rb [options] template"
 
   # Define the options, and what they do
   options[:all] = false
   opts.on( '-a', '--all', 'Run template against all records regardless of whether all fields referenced are present' ) do
      options[:all] = true
   end
 
   options[:query] = nil
   opts.on( '-q', '--query QUERY', 'A MongoDB JSON query to use to select records that the template will be run against' ) do |query|
     options[:query] = query
   end
 
   options[:template] = nil
   opts.on( '-t', '--template TEMPLATE', 'The Template to use' ) do|template|
     options[:template] = template
   end
 
   # This displays the help screen, all programs are
   # assumed to have this option.
   opts.on( '-h', '--help', 'Display this screen' ) do
     puts opts
     exit
   end
 end
 
 optparse.parse!
 if options[:template] == nil
    #puts opts
    exit
 end
 
 inteldb_config = ParseConfig.new('/etc/inteldb/inteldb.conf')
        $adminEmail = inteldb_config.get_value('adminEmail')
        $institution_name = inteldb_config.get_value('institutionName')
        
        $emailReceiveMethod = inteldb_config.get_value('emailReceiveMethod')
        $emailSendMethod = inteldb_config.get_value('emailSendMethod')
        $emailServer = inteldb_config.get_value('emailServer')
        $emailUser = inteldb_config.get_value('emailUser')
        $emailPassword = inteldb_config.get_value('emailPassword')
        
        $mongoServer = inteldb_config.get_value('dbServer')
        $mongoPort = inteldb_config.get_value('dbPort')
        
        if $mongoServer == nil || $mongoServer == ''
          $mongoServer = 'localhost'
        end
        
        if $mongoPort == nil || $mongoPort == ''
          $mongoPort = '27017'
        end
        
        #The MongoDB Connection
        @@intelDB = Connection.new($mongoServer, $mongoPort).db('inteldb')
 
 ExportLibrary.RunRule(options[:template], @@intelDB['intel'].find()).each do |line|
   puts line
 end
 
 
 


