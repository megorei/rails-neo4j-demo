class DrugsController < ApplicationController
  def index
    @drugs = DrugAdvisor.new.find(symptoms, age, allergies)
    render json: @drugs.map(&:name)
  end
end