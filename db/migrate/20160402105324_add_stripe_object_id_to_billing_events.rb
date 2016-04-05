class AddStripeObjectIdToBillingEvents < ActiveRecord::Migration
  disable_ddl_transaction!
  def change
    add_column :billing_events, :stripe_object_id, :text
    add_index :billing_events, :stripe_object_id, algorithm: :concurrently
  end
end
