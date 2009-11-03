class CreatePfeedDeliveries < ActiveRecord::Migration
  def self.up
   
    create_table :pfeed_deliveries do |t|
     t.integer :pfeed_receiver_id
     t.string :pfeed_receiver_type
     t.integer :pfeed_item_id       
     t.integer :location_id  
     t.decimal :at_distance , :precision => 15, :scale => 10  
     t.boolean :archived, :default => false
     t.timestamps
   end
  end

  def self.down
     drop_table :pfeed_deliveries
  end
end
