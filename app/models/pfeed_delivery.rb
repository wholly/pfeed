class PfeedDelivery < ActiveRecord::Base
  belongs_to :pfeed_receiver, :polymorphic => true
  belongs_to :pfeed_item      
  before_save :calculate_distance
  belongs_to :location 
  
  private
  def calculate_distance   
  #debugger  
    if pfeed_item.originator.location != nil  && pfeed_receiver.location != nil
      self.at_distance =  pfeed_receiver.location.distance_from pfeed_item.originator.location
      self.location =  pfeed_item.originator.location 
    end  
  end
  
end
