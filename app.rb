#!/usr/bin/env

require 'rubygems'
require 'sinatra'
require 'thin'
require 'rack'
require 'parseconfig'
require 'json'
require 'mongo'
require 'digest/sha1'
require 'date'
require 'pony'
require 'prawn'
require_relative './library/ExportLibrary'

class IntelDB < Sinatra::Base
    include Rack::Utils
    include Mongo
    include Pony
     
    #Configuration runs at the beginning of a request
    configure do
        #Sets the cookie that handles session authentication. Secret keeps the cookies valid between server restarts
        use Rack::Session::Cookie, :key => 'inteldb.rack.session', :secret => '33a2316d2010fb8b3dc916ec7d9dfa39fb6332b3'
        set :public_folder, 'public'
        enable :logging
        set :public_folder, File.dirname(__FILE__) + '/public'
        set :static, true
        set :public, 'public'
        $debugging = true
        
        #Configuration file parsing object, specifies the path to the file (/etc/ is the default folder for conf files on linux/unix)
        inteldb_config = ParseConfig.new('/etc/inteldb/inteldb.conf')
        $adminEmail = inteldb_config.get_value('adminEmail')
        $institution_name = inteldb_config.get_value('institutionName')
        $url = inteldb_config.get_value('url')
        
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
        
    end

    
    #Redirects initial requests to an attempt for the authenticated index
    get '/' do
        redirect '/authenticated/index'
    end

    #Login Page
    get '/login' do
        erb :login, :layout => false
    end

    #When a user has entered information into the login page, validates authentication information
    post '/login' do 
        username = params[:txtUserName]
        password = params[:txtPassword]
        #Username/Password validation, if valid, set cookie for session and redirect to authenticated section
        if IntelDB.AuthenticateUser?(username, password)
            session[:username] = username
            IntelDB.AddLog(1, username, 'Successful Login', "The user '#{username}' logged in successfuly from the IP address " + request.ip)
            redirect '/authenticated/index'
        end
        #Well, they failed the authentication. Show the configuration file email address for the administrator
        IntelDB.AddLog(2, username, 'Failed Login', "The user '#{username}' failed to log in from the IP address " + request.ip)
        @errormessage = "Invalid username or password." +
                        "<br>" +
                        "If you feel this is an error, please contact your administrator at <a href='mailto:#{$adminEmail}'>#{$adminEmail}</a>"
        erb :login, :layout => false
    end

    #Logout URL, delete the session cookie and redirect to login
    get '/logout' do
        IntelDB.AddLog(3, session[:username], 'A User Logged Out', "The user '#{session[:username]}' logged out from the IP address " + request.ip)
        session.clear
        redirect '/login'
    end

    #This rule blocks any requests to authenticated pages unless the user has a valid session cookie. All URLS
    #below this are considered authenticated now.
    get '/authenticated/*' do
        #pass unless session[:username] == nil || session[:username] == ''
        pass if IsUserAuthenticated?
        redirect '/login'
    end

    #Main Authenticated view, shows intel data
    get '/authenticated/index/?' do
        erb :default
    end

    #The "add data" page
    get '/authenticated/add-data/?' do
        erb :addData
    end
    
    #The "User Preferences" page
    get '/authenticated/user-management/?' do
        erb :userPreferences
    end
    
    #In case a user somehow gets here, redirect them to the right place
    get '/authenticated/change-password/?' do
      redirect '/authenticated/user-management'
    end
    
    #Occurs when a user posts to the change password page
    post '/authenticated/change-password/?' do
        current_password = params[:txtCurrentPassword]
        new_password = params[:txtNewPassword]
        repeat_password = params[:txtRepeatPassword]
        if !IntelDB.AuthenticateUser?(session[:username], current_password) || new_password != repeat_password
          @errormessage = "Invalid current password or passwords do not match" +
                        "<br>" +
                        "If you feel this is an error, please contact your administrator at <a href='mailto:#{$adminEmail}'>#{$adminEmail}</a>"
          IntelDB.AddLog(6, session[:username], 'Failed Password Change', "The user '#{session[:username]}' failed to change their password from the IP address " + request.ip)
          erb :userPreferences
        
        else
            IntelDB.ChangePassword(session[:username], new_password)
            IntelDB.AddLog(5, session[:username], 'Successful Password Change', "The user '#{session[:username]}' successfully changed their password from the IP address " + request.ip)
            @result = "Success"
            erb :userPreferences
        end
        
    end
    
    #The "Add User" post method
    post '/authenticated/add-user/?' do
        unless @@intelDB['users'].find_one({:username => params[:txtUserName]}) != nil
            newPassword = params[:txtUserName] + rand(1000).to_s + params[:txtUserName]
            newPassword = Digest::SHA1.hexdigest(newPassword)
            @@intelDB['users'].insert({:username => params[:txtUserName]})
            IntelDB.ChangePassword(params[:txtUserName], newPassword)
            Pony.mail(
                  :via => :smtp, 
                  :to => params[:txtUserName], 
                  :from => "#{$institution_name} IntelDB <#{$emailUser}>",
                  :subject => "An Account has been created for you", 
                  :html_body => "A New account has been created for you on IntelDB (<a href='#{$url}'>#{$url}</a>). Your username is your email address. Your password is " + newPassword + "<br /><br />Please change your password as soon as you login",
                 )
        end
        erb :userPreferences
    end
    
    #The page for the user to view the audit log
    get '/authenticated/view-log/?' do
        erb :viewLog
    end
    
    #the Web service for JQGrid
    get '/authenticated/log/:limit/:skip' do
        @@intelDB['log'].find().sort([[:_id, -1]]).limit(params[:limit].to_i).skip(params[:skip].to_i).to_a.to_json
    end
    
    #Data POSTING to the add-data page
    #NOTE: for testing purposes, we are not validating, just inserting
    post '/authenticated/add-data' do
        #Split the tags on semicolon, space, or comma and remove the split chars
        tags = (params['tags'] == nil ? [] : params['tags'].split(/(,\s?|;\s?|\s)/))
        tags = tags.delete_if {|x| x =~ /(;|,|\s)\s?/}
        #Clone the posted hash in order to alter it
        toInsert = params.clone
        toInsert.delete('tags')
        toInsert['tags'] = tags
        @@intelDB['intel'].insert(toInsert)
        "Success"
    end

    #The schema management/add schema item page
    get '/authenticated/manage-schema/?' do
        erb :manageSchema
    end
    
    #Data Posting to manage-schema page
    #NOTE: for testing purposes, we are not validating, just inserting
    post '/authenticated/manage-schema/?' do
        toInsert = {
          :field_name => params['txtFieldName'],
          :display_name => params['txtDisplayName'],
          :description => params['txtDescription'],
          :added_by => params['txtAddedBy'],
          :validation_expression => params['txtValidationExpression'],
          :validation_required => params['checkRequired'],
          :default_field => params['checkDefault']
        }
        @@intelDB['schema'].update({:field_name => toInsert[:field_name]}, toInsert, {:upsert => true})
        "Success"
    end

    #Returns a JSON object representing the requested intelItem ID
    get '/authenticated/services/intelItem/:id/?' do
        get_item_by_id(params[:id]).to_json
    end

    #Returns a JSON object representing all of the intel items from AFTER the given date
    get '/authenticated/services/intelList/since/:date/?' do
        
    end

    #Returns a JSON object representing all of the intel items in reverse date order (soonest first) and then limiting and skipping (like an SQL Query)
    #Used for the pagination.
    get '/authenticated/services/intelList/query/:limit/:skip/?' do
        @@intelDB['intel'].find().limit(params[:limit].to_i).skip(params[:skip].to_i).sort([['_id', -1]]).to_a.to_json
    end
    
    #Returns intel items that match the specified tag with limit and skip for pagination
    get '/authenticated/services/intelList/tag/:tag/:limit/:skip/?' do
        @@intelDB['intel'].find({:tags => params[:tag]}).limit(params[:limit].to_i).skip(params[:skip].to_i).sort([['_id', -1]]).to_a.to_json
    end

    #Returns the list of navigation tags to be used
    get '/authenticated/services/tagList/?' do
        @@intelDB['intel'].distinct('tags').to_json
    end
    
    #Returns the list of schema items in the database
    get '/authenticated/services/schemaList/?' do
        get_schema_list().to_json
    end
    
    #Returns the number of records currently in the database, used to create the pagination
    get '/authenticated/services/recordCount' do
       @@intelDB['intel'].count().to_json
    end
    
    #Returns the schema information for the specified field_name
    get '/authenticated/services/schemaItem/:field_name' do
        @@intelDB['schema'].find_one({:field_name => params[:field_name]}).to_json
    end
    
    #Emails the specified intel item to the recipients
    post '/authenticated/services/emailIntelItem/?' do
        intel_item = get_item_by_id(params[:id])
        schema = get_schema_list()
        email_body = ""
        intel_item.each do |key, value|
          description = schema.select do |item|
            item['field_name'] == key
          end
          unless description.length == 0
            email_body = email_body + "<b>#{description[0]['display_name']}:</b> #{value}<br><br>"
          end
        end
        Pony.mail(
                  :via => :smtp, 
                  :to => params[:to], 
                  :from => "#{$institution_name} IntelDB <#{$emailUser}>",
                  :subject => intel_item['source_institution'] + " - " + intel_item['title'], 
                  :html_body => email_body,
                  :attachments => {'mongo_item.txt' => intel_item.to_json}
                 )
        IntelDB.AddLog(100, session[:username], 'Intel Item was Emailed', "The IntelItem titled #{intel_item['title']} was sent to #{params[:to]}")
        "Success"
    end
    
    #Returns a PDF version of the specified IntelItem
    get '/authenticated/services/pdf/:id/*' do content_type('application/pdf')
        intel_item = get_item_by_id(params[:id])
        schema = get_schema_list()
        pdf = Prawn::Document.new(:info => {
          :Title => intel_item['title'],
          :Author => intel_item['source_individual'],
          :Creator => "IntelDB", 
          :Producer => "Prawn",
          :CreationDate => Time.now,
        })
        font_path = "./fonts/helveticaneue.ttf"
        font_bold_path = "./fonts/helveticaneuebold.ttf"
        pdf.define_grid(:columns => 10, :rows => 10, :gutter => 10)
        pdf.font('Helvetica', :style => :normal)
        pdf.grid([0,0], [0,9]).bounding_box do 
          pdf.font_size(8)
          pdf.text "Intelligence Data Exported from the " + $institution_name + " IntelDB" 
          pdf.text " "
          pdf.font_size(18)
          pdf.text intel_item['source_institution'] + ' - "' + intel_item['title'] + '"'
        end
        pdf.grid([1,0], [9,2]).bounding_box do
            pdf.font_size(11)
              pdf.formatted_text [ 
                      {:text => "Intelligence Added On: ", :styles => [:bold]},
                      {:text => intel_item['date_added']}
              ]
              pdf.formatted_text [ 
                      {:text => "Intelligence Expires: ", :styles => [:bold]},
                      {:text => intel_item['date_expires']}
              ]
            #pdf.stroke_horizontal_rule
        end
        pdf.grid([1,3], [9,9]).bounding_box do
            pdf.font_size(11)
            intel_item.each do |key, value|
              description = schema.select do |item|
                item['field_name'] == key && key != 'title' && key != 'context' && key != 'date_added' && key != 'date_expires' && key != 'source_institution' && key != 'tags'
              end
              unless description.length == 0
                pdf.formatted_text [ 
                      {:text => description[0]['display_name'] + ": ", :styles => [:bold]},
                      {:text => value.to_s, :align => :right}
                ]
              end
            end
            pdf.text " "
            #pdf.font(font_bold_path)
            pdf.text "Tags:", :style => :bold
            pdf.table [intel_item['tags'].to_a], 
                      :row_colors => ["F89406"], 
                      :cell_style => {:padding => [2, 3, 2, 3], 
                                      :text_color => "FFFFFF",
                                      :border_width => 2,
                                      :border_color => "FFFFFF",
                                      :font_style => :bold
                      }
                      
            pdf.text " "
            pdf.text intel_item['context'] == nil ? '' : intel_item['context']
        end
        pdf.encrypt_document
        pdf.render
    end
    
    #Takes the posted file and attempts to import it into the MongoServer
    post '/authenticated/services/dataImport/?' do
        begin
            insertJSONintoMongo(params['fileInput'][:tempfile].read, 'intel')
        rescue
            @fileInputError = "There was an error with the file you uploaded, please check the source/contents and try again"
        end
        
        if @fileInputError != nil
            erb :addData
        else
          redirect '/authenticated/index'
        end
    end
    
    #The export data page
    get '/authenticated/export-data/?' do
        erb :exportData
    end
    
    post '/authenticated/services/runRule/?' do
        ExportLibrary.RunRule(params[:rule], @@intelDB['intel'].find().to_a).to_json
    end
    
    get '/authenticated/services/exportTemplateList/?' do
        @@intelDB['templates'].find().to_a.to_json
    end
    
    post '/authenticated/services/saveExportTemplate/?' do
        @@intelDB['templates'].insert({:name => params[:title].gsub(" ", "-"), :title => params[:title], :template => params[:template]});
        "Success"
    end
    
    get '/authenticated/services/getTemplate/:name/?' do
        @@intelDB['templates'].find_one({:name => params[:name]}).to_json
    end
    
#These are methods, not web services from here on out
    
    def insertJSONintoMongo(json, collection)
        result = JSON.parse(json)
        result['_id'] = BSON::ObjectId(result['_id']['$oid'])
        @@intelDB[collection].insert(result)
    end
    
    #Checks to see if the given username and password is valid
    def IntelDB.AuthenticateUser?(username, password)
        db_user = @@intelDB['users'].find_one({:username => username})
        return (db_user != nil && db_user['password'] == Digest::SHA1.hexdigest(password))
    end
    
    #Checks to see if the current User is authenticated
    def IsUserAuthenticated?
        return session[:username] != nil && session[:username] != ''
    end

    #Change the specified user's password
    def IntelDB.ChangePassword(username, password)
        user = @@intelDB['users'].find_one({:username => username})
        unless user == nil
            user[:password] = Digest::SHA1.hexdigest(password)
            @@intelDB['users'].update({:username => username}, user)
        end
    end
    
    #prints a debug statement if debugging
    def debugPrint(toPrint)
        if $debugging
          puts toPrint
        end
    end
    
    #Adds an item to the log
    def IntelDB.AddLog(eventID, user, title, entry)
        timeNow = DateTime.now
        @@intelDB['log'].insert({:ts => timeNow.rfc3339(2), :eventID => eventID, :user => user, :title => title, :entry => entry,})
    end
    
    #Returns an intel item by ID
    def get_item_by_id(id)
        @@intelDB['intel'].find_one({:_id => BSON::ObjectId(id)})
    end
    
    #Returns the schema list for mapping items to their display information
    def get_schema_list()
        @@intelDB['schema'].find({}, {:fields => 
            {
              :field_name => 1, 
              :_id => 0, 
              :display_name => 1, 
              :validation_expression => 1, 
              :validation_required => 1,
              :description => 1
            }}).to_a
    end
    
end







