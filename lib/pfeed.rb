#snippet: https://gist.github.com/89e92409ca9016d2d919

module ParolkarInnovationLab
  module SocialNet
    def self.included(base)
      base.extend ParolkarInnovationLab::SocialNet::ClassMethods
    end
    
    module ClassMethods
                  
      def emits_pfeeds arg_hash # {:on => [] , :for => [:itself , :all_in_its_class]}
        include ParolkarInnovationLab::SocialNet::InstanceMethods
 
        method_name_array = arg_hash[:on]
        class_inheritable_hash :pfeed_audience_hash
        
        method_name_array.each{|method_name| register_pfeed_audience(method_name,arg_hash[:for])  }

        

        method_name_array.each { |method_name|
          method, symbol = method_name.to_s.split /(\!|\?)/
          symbol = '' if symbol.nil?
                    
          method_to_define = method + '_with_pfeed' + symbol
          method_to_be_called = method + '_without_pfeed' + symbol
          eval %[
               
             module ::ParolkarInnovationLab::SocialNet::PfeedTemp::#{self.to_s} 
              def #{method_to_define}(*a, &b)
                returned_result = #{method_to_be_called}(*a , &b)
                method_name_in_past_tense = "#{ParolkarInnovationLab::SocialNet::PfeedUtils.attempt_pass_tense(method)}"
                PfeedItem.log(self,"#{method_name}",method_name_in_past_tense,returned_result,*a,&b) 
                returned_result
              end
             end    
          ] 
            
        }
        
        #TODO : Pfeed.log(self,"#{method_name}",method_name_in_past_tense,returned_result,*a,*b)  : this is to be done in a different thread in bg to boost performance & also needs exception handling such that parent call never breaks
        
        include "::ParolkarInnovationLab::SocialNet::PfeedTemp::#{self.to_s}".constantize # why this? because "define_method((method + '_with_pfeed' + symbol).to_sym) do |*a , &b|" generates syntax error in ruby < 1.8.7 
        
        method_name_array.each { |method_name|
          method, symbol = method_name.to_s.split /(\!|\?)/
          symbol = '' if symbol.nil?
          alias_method_chain (method + symbol), :pfeed
        }
         
        has_many :pfeed_items , :as => :originator , :dependent => :destroy   #when originator is deleted the pfeed_items gets destroyed too
         
          
      end
     
      def receives_pfeed
        has_many :pfeed_deliveries , :as => :pfeed_receiver 
       # has_many :pfeed_inbox, :class_name => 'PfeedItem', :foreign_key => "pfeed_item_id" , :through => :pfeed_deliveries , :source => :pfeed_item

	write_inheritable_attribute(:is_pfeed_receiver,true)
        class_inheritable_reader :is_pfeed_receiver
      end
    
      def register_pfeed_audience(method_name,audeince_arr)
         
         write_inheritable_hash(:pfeed_audience_hash, { method_name.to_sym => audeince_arr }) # this does a merge
         
      end 
    end
    
    module PfeedTemp
      # Required for temporarily injecting new methods
    end  
    module InstanceMethods
    
      def itself
	      self
      end

      def all_in_its_class
        self.class.find :all
      end    
      
      def pfeed_recent_item_timestamp  
        self.pfeed_deliveries.last.created_at
      rescue
        nil
      end

      def pfeed_recent_delivery_id(pfeedid)  
        self.pfeed_deliveries.find_by_pfeed_item_id(pfeedid.to_i).id
      rescue
        nil
      end

      def pfeed_inbox(options)    
        default_options = {:within_distance => 6378.10, :since => 10.years.ago, :limit => 15}   
        options = default_options.merge(options)
        conditions = []
        condition_str = ""
        condition_str << "created_at > ? and at_distance < ? "
        condition_str << "and id < ?" if options.has_key?(:from_id)
        condition_str << " and archived = false" if !(options.has_key?(:includes_archived) && options[:includes_archived])
        conditions << condition_str 
        conditions << options[:since] << options[:within_distance]
        conditions << options[:from_id] if options.has_key?(:from_id)
        #pfeed_deliveries_arr = self.pfeed_deliveries.find(:all,:conditions => ['created_at > ? and at_distance < ?', options[:since],options[:within_distance]],:order => "created_at DESC ")
        pfeed_deliveries_arr = self.pfeed_deliveries.find(:all, :limit => options[:limit], :conditions => conditions, :order => "created_at DESC")
        pfeed_items = []

        pfeed_deliveries_arr.each {|pd|
          pfeed_item = pd.pfeed_item
          pfeed_item.distance =  pd.at_distance
          pfeed_items << pfeed_item
          }
        return pfeed_items
      end
      
      
     
      private
        #let private methods come here
    end
  end
end



