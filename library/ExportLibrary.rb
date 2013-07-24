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
require 'mongo'

class ExportLibrary
    
    #Takes a rule string and a list of intel items and returns a list of strings containing the output results
    def ExportLibrary.RunRule(rule, intel_items)
        fields = []
        output = []
        rule.scan(/{\:([^ ]+)}/).each do |match|
            fields.push match[0]
        end
        intel_items.each do |item|
            has_all_fields = true
            this_output = rule.clone
            fields.each do |field|
                if ExportLibrary.IsFunctionField?(field)
                    this_output.gsub!("{:" + field + "}", GetFunctionResults(field).to_s)
                elsif item[field] == nil
                    has_all_fields = false
                    break
                else
                    this_output.gsub!("{:" + field + "}", item[field])
                end
            end
            if !has_all_fields
                next
            end
            output.push this_output
        end
        output
    end
    
    #Returns true if the field provided is a "function", false otherwise
    def ExportLibrary.IsFunctionField?(field)
        functions = ['random_sid', 'random_digit']
        return functions.include? field
    end
    
    #Returns the value of a "function"
    def ExportLibrary.GetFunctionResults(name)
        prng = Random.new
        if name == 'random_sid'
            prng.rand(1000000..9999999)
        elsif name == 'random_digit'
            prng.rand(0..9)
        else
            nil
        end
    end
    
end