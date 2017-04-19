class Plan < ApplicationRecord
  has_many :users

  def trial?
    self.stripe_id == "trial"
  end

  def period
    name.gsub(/ly$/, '').downcase
  end

end
