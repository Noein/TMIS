# coding: UTF-8
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
require 'contracts'
include Contracts
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class Lecturer < ActiveRecord::Base
  has_many :studies
  has_many :emails, :as => :emailable

  Contract None => String
  def to_s
    "#{self.surname} #{self.name unless self.name.nil?} #{self.patronymic unless self.patronymic.nil?}"
  end
end
