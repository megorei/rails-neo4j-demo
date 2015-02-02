class DoctorsController < ApplicationController
  def index
    results = DoctorAdvisor.new.find(symptoms, age, allergies, latitude, longitude)
    @doctors = results.inject({}) do |hash, pair|
      doctor, distance = pair
      hash.merge!(doctor.name => distance.round(2))
    end
    render json: @doctors
  end
end