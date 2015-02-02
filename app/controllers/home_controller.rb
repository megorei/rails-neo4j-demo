class HomeController < ApplicationController
  def index
    @symptoms  = Symptom.all
    @allergies = Allergy.all
  end
end