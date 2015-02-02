class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  private

  def symptoms
    params[:symptoms] || []
  end

  def allergies
    params[:allergies] || []
  end

  def age
    params[:age].to_i
  end

  def latitude
    params[:latitude].to_f
  end

  def longitude
    params[:longitude].to_f
  end
end
