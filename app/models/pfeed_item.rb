class PfeedItem < ActiveRecord::Base
                                   

  #before_validation_on_create :pack_data
  serialize :data, Hash
  serialize :participants, Array
   
  belongs_to :originator, :polymorphic => true
  belongs_to :participant, :polymorphic => true


  has_many :pfeed_deliveries, :dependent => :destroy 
  
  attr_accessor :temp_references # this is an temporary Hash to hold references to temporary Objects   
  attr_accessor :distance # this is a very special attribute which is used by pfeed_inbox to populate the distance from pfeed_deliveries
  attr_accessor :delivered_at  

  def self.log(ar_obj,method_name,method_name_in_past_tense,returned_result,*args_supplied_to_method,&block_supplied_to_method)
     #puts "#{ar_obj.class.to_s},#{method_name},#{method_name_in_past_tense},#{returned_result},#{args_supplied_to_method.length}"
     
      temp_references = Hash.new
      temp_references[:originator] = ar_obj
      temp_references[:participant] = nil
      temp_references[:participant] = args_supplied_to_method[0] if args_supplied_to_method &&  args_supplied_to_method.length >= 1 && args_supplied_to_method[0].class.superclass.to_s == "ActiveRecord::Base"

      pfeed_class_name = "#{ar_obj.class.to_s.underscore}_#{method_name_in_past_tense}".camelize # may be I could use .classify
      pfeed_class_name = "Pfeeds::"+pfeed_class_name
      contstructor_options = { :originator_id => temp_references[:originator].id , :originator_type => temp_references[:originator].class.to_s , :participant_id => (temp_references[:participant] ? temp_references[:participant].id : nil) , :participant_type => (temp_references[:participant] ? temp_references[:participant].class.to_s : nil) } # there is a reason why I didnt use {:originator => temp_references[:originator]} , if originator is new record it might get saved here un intentionally


      p_item =  nil
      begin
        #puts "Attempting to create object of  #{pfeed_class_name} "
        p_item =  pfeed_class_name.constantize.new(contstructor_options) 
        p_item.temp_references =  temp_references
      rescue NameError
        #puts "could not find class #{pfeed_class_name} , hence using default Pfeed"
        p_item = PfeedItem.new(contstructor_options) 
      end   

      p_item.pack_data(method_name,method_name_in_past_tense,returned_result,*args_supplied_to_method,&block_supplied_to_method)


      p_item.save
      #puts "Trying to deliver to #{ar_obj}  #{ar_obj.pfeed_audience_hash[method_name.to_sym]}"
      p_item.attempt_delivery(ar_obj,ar_obj.pfeed_audience_hash[method_name.to_sym])   # attempting the delivery of the feed

  end  
  
  def attempt_delivery (ar_obj,method_name_arr)
    if (defined? Delayed) == "constant" && (respond_to? :send_later) == true   #this means Delayed_job exists , so make use of asynchronous delivery of pfeed
      send_later(:deliver,ar_obj,method_name_arr)  
    else  # regular instant delivery
      send(:deliver,ar_obj,method_name_arr)    
    end


  end

  def deliver(ar_obj,method_name_arr)
    all_receivers = Array.new

    method_name_arr.each { |method_name|
      result_obj = ar_obj.send(method_name)  
   
      if result_obj.is_a?(Array)
         result_obj.each { |result_ar_obj| all_receivers.push(result_ar_obj) if (result_obj != nil && result_ar_obj.is_pfeed_receiver && !all_receivers.include?(result_ar_obj))}
      else
         all_receivers.push(result_obj) if (result_obj != nil && result_obj.is_pfeed_receiver && !all_receivers.include?(result_obj))
      end	

    }  

    all_receivers.each { |r_obj|
      
      delivery = PfeedDelivery.new
      
      if ! r_obj.new_record?
        delivery.pfeed_item = self
        delivery.pfeed_receiver = r_obj
        delivery.save!
      end
    }

  end
  def accessible?
    true 
  end
  def view_template_name 
    "#{self.class.to_s.underscore}".split("/").last
  end
  
  def audience
    # return list of objects to whom feed gets delivered
  end
  
  def pack_data(method_name,method_name_in_past_tense,returned_result,*args_supplied_to_method,&block_supplied_to_method) 
    self.data = {} if ! self.data
    action_string = method_name_in_past_tense.humanize.downcase
    hash_to_be_merged = {:action_string => action_string}
    
    self.data.merge!  hash_to_be_merged
  end
  
  def guess_identification(ar_obj)
    possible_attributes = ["username","login","name","company_name","first_name","last_name","login_name","login_id","given_name","nick_name","nick","short_name"]
    
    possible_attributes = self.data[:config][:identifications] + possible_attributes if self.data[:config] && self.data[:config][:identifications] && self.data[:config][:identifications].is_a?(Array)
    matched_name = ar_obj.attribute_names & possible_attributes # intersection of two sets
    
    identi = nil
    
    identi =  ar_obj.read_attribute(matched_name[0]) if identi == nil && matched_name.length > 0
    identi =  "#{ar_obj.class.to_s}(\##{ar_obj.id})"  if identi == nil || identi.blank?
    
    return identi
  rescue
    return "UNKNOWN"  
  end  
end
