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