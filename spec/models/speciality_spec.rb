#~~~~~~~~~~~~~~~~~~~~~~~~~~
require 'rspec'
require_relative '../config'
#~~~~~~~~~~~~~~~~~~~~~~~~~~
require 'tmis/engine/database'
require 'tmis/engine/models/speciality'
#~~~~~~~~~~~~~~~~~~~~~~~~~~
describe Speciality do
  before(:all) do
    @speciality = create(:speciality)
    @speciality_subject = create(:speciality_subject, speciality: @speciality)
  end

  describe 'Speciality associations' do
    it 'Speciality.speciality_subjects' do
      @speciality.speciality_subjects.last.should eq(@speciality_subject)
    end
    it 'Speciality_subject.speciality' do
      @speciality_subject.speciality.should eq(@speciality)
    end
  end

  after(:all) do
    Speciality.delete_all
  end
end
