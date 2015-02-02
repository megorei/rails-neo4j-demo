## Rails demo app

### Create Rails app

~~~
gem install rails
~~~

~~~
rails new . --skip-active-record
~~~

### Setup neo4j

**config/application.rb**

~~~ruby
require "neo4j/railtie"
~~~

~~~
rake neo4j:install[community-2.1.6]
~~~

~~~
rake neo4j:start
~~~

### Setup database

**config/environments/development.rb**

~~~ruby
  config.neo4j.session_type = :server_db
  config.neo4j.session_path = 'http://localhost:7474'
~~~

**db/seeds.rb**

~~~ruby
query_string = <<query
  create
  (_6:DrugClass  {id: 1, name:"Bronchodilators"}),
  (_7:DrugClass  {id: 2, name:"Corticosteroids"}),
  (_8:DrugClass  {id: 3, name:"Xanthine"}),
  (_9:Drug   {id: 1, name:"Salbutamol"}),
  (_10:Drug  {id: 2, name:"Terbutaline"}),
  (_11:Drug  {id: 3, name:"Bambuterol"}),
  (_12:Drug  {id: 4, name:"Formoterol"}),
  (_13:Drug  {id: 5, name:"Salmeterol"}),
  (_14:Drug  {id: 6, name:"Beclometasone"}),
  (_15:Drug  {id: 7, name:"Budesonide"}),
  (_16:Drug  {id: 8, name:"Ciclesonide"}),
  (_17:Drug  {id: 9, name:"Fluticasone"}),
  (_18:Drug  {id: 10, name:"Mometasone"}),
  (_19:Drug  {id: 11, name:"Betametasone"}),
  (_20:Drug  {id: 12, name:"Prednisolone"}),
  (_21:Drug  {id: 13, name:"Dilatrane"}),
  (_22:Allergy  {id: 1, name:"Hypersensitivity to Betametasone"}),
  (_23:Pathology  {id: 1, name:"Asthma"}),
  (_24:Symptom  {id: 1, name:"Wheezing"}),
  (_25:Symptom  {id: 2, name:"Chest tightness"}),
  (_26:Symptom  {id: 3, name:"Cough"}),
  (_27:Doctor  {id: 1, latitude:48.8573,longitude:2.35685,name:"Irving Matrix"}),
  (_28:Doctor  {id: 2, latitude:46.83144,longitude:-71.28454,name:"Jack McKee"}),
  (_29:Doctor  {id: 3, latitude:48.86982,longitude:2.32503,name:"Michaela Quinn"}),
  (_30:DoctorSpecialization  {id: 1, name:"Physician"}),
  (_31:DoctorSpecialization  {id: 2, name:"Angiologist"}),
  _6-[:cures {age_max:60,age_min:18,indication:"Adult asthma"}]->_23,
  _7-[:cures {age_max:18,age_min:5,indication:"Child asthma"}]->_23,
  _8-[:cures {age_max:60,age_min:18,indication:"Adult asthma"}]->_23,
  _9-[:belongs_to_class]->_6,
  _10-[:belongs_to_class]->_6,
  _11-[:belongs_to_class]->_6,
  _12-[:belongs_to_class]->_6,
  _13-[:belongs_to_class]->_6,
  _14-[:belongs_to_class]->_7,
  _15-[:belongs_to_class]->_7,
  _16-[:belongs_to_class]->_7,
  _17-[:belongs_to_class]->_7,
  _18-[:belongs_to_class]->_7,
  _19-[:belongs_to_class]->_6,
  _19-[:belongs_to_class]->_7,
  _19-[:may_cause_allergy]->_22,
  _20-[:belongs_to_class]->_7,
  _21-[:belongs_to_class]->_8,
  _23-[:may_manifest_symptoms]->_24,
  _23-[:may_manifest_symptoms]->_25,
  _23-[:may_manifest_symptoms]->_26,
  _27-[:specializes_in]->_31,
  _28-[:specializes_in]->_31,
  _29-[:specializes_in]->_30,
  _30-[:can_prescribe]->_7,
  _31-[:can_prescribe]->_6
query

Neo4j::Session.current.query(query_string)
~~~

**Rakefile**
~~~ruby
namespace :db do
  task seed: :environment do
    seed_file = File.join('db/seeds.rb')
    load(seed_file) if File.exist?(seed_file)
  end

  task clear: :environment do
    Neo4j::Session.current.query('MATCH (n) OPTIONAL MATCH (n)-[r]-() DELETE n,r')
  end
end
~~~

### Setup models

**models/concerns/integer_id.rb**

~~~ruby
module IntegerId
  def self.included(base)
    base.class_eval do
      id_property :id, on: :generate_id

      def generate_id
        self.class.order(id: :desc).first.try(:id).to_i + 1
      end
    end
  end
end
~~~

~~~ruby
class Pathology
  include Neo4j::ActiveNode
  include IntegerId

  has_many :in, :drug_classes, type: :cures
end

class Symptom
  include Neo4j::ActiveNode
  include IntegerId

  has_many :in, :pathologies, type: :may_manifest_symptoms
end

class DrugClass
  include Neo4j::ActiveNode
  include IntegerId

  has_many :in, :drugs, type: :belongs_to_class
end

class Drug
  include Neo4j::ActiveNode
  include IntegerId

  property :name
end

class Doctor
  include Neo4j::ActiveNode
  include IntegerId

  property :name
end
~~~

### Use cases


**app/advisors/drug_advisor.rb**

~~~ruby
class DrugAdvisor
  def find(symptom_names, age, allergy_names = [])
    find_query(symptom_names, age, allergy_names).pluck('DISTINCT(drug)')
  end

  def find_query(symptom_names, age, allergy_names = [])
    Symptom.all.where(name: symptom_names).
      pathologies.
      drug_classes(:drug_class, :cures).where('cures.age_min <= {age} AND {age} < cures.age_max').
      params(age: age).
      drugs.query_as(:drug).
        match(allergy: :Allergy).
        where('(NOT (drug)-[:may_cause_allergy]->(allergy) OR NOT(allergy.name IN {allergy_names}))').
        params(age: age, allergy_names: allergy_names)
  end
end
~~~

**app/advisors/doctor_advisor.rb**

~~~ruby
class DoctorAdvisor
  def find(symptom_names, age, allergy_names = [], latitude = nil, longitude = nil)
    DrugAdvisor.new.find_query(symptom_names, age, allergy_names).
      match('(doctor:Doctor)-->(:DoctorSpecialization)-[:can_prescribe]->(drug_class)').
      return('DISTINCT(doctor) AS doctor',
             '2 * 6371 * asin(sqrt(haversin(radians({lat} - COALESCE(doctor.latitude,{lat}))) + cos(radians({lat})) * cos(radians(COALESCE(doctor.latitude,90)))* haversin(radians({long} - COALESCE(doctor.longitude,{long}))))) AS distance').
      params(lat: latitude, long: longitude).
      order('distance ASC').
      each_with_object({}) do |result, hash|
        hash[result.doctor] = result.distance
      end
  end
end
~~~

### Routes and controllers

**config/routes.rb**

~~~ruby
Rails.application.routes.draw do
  resources :drugs
  resources :doctors
  root to: 'home#index'
end
~~~

**app/controllers/application_controller.rb**

~~~ruby
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

~~~

**app/controllers/home_controller.rb**

~~~ruby
class HomeController < ApplicationController
  def index
    @symptoms  = Symptom.all
    @allergies = Allergy.all
  end
end
~~~

**app/controllers/drugs_controller.rb**

~~~ruby
class DrugsController < ApplicationController
  def index
    @drugs = DrugAdvisor.new.find(symptoms, age, allergies)
    render json: @drugs.map(&:name)
  end
end
~~~

**app/controllers/doctors_controller.rb**

~~~ruby
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
~~~

### Views and assets

**app/views/layouts/application.html.haml**

~~~haml
%html
  %head
    %meta(charset='utf-8')
    %meta(http-equiv='X-UA-Compatible' content='IE=Edge,chrome=1')
    %meta(name='viewport' content='initial-scale=1.0')
    %title Sinatra Demo App. Doctor Finder
    = stylesheet_link_tag    'application', media: 'all', 'data-turbolinks-track' => true
    = javascript_include_tag 'application', 'data-turbolinks-track' => true
  %body
    %header
    = yield
~~~

**app/views/home/index.html.haml**

~~~haml
.advisors.container
  .advisor.panel.panel-default
    .panel-heading Find drugs and doctors
    .panel-body
      %p
        Please enter age, symptoms and allergies(optional) to find drugs and doctors
      %form.form-horizontal
        .form-group
          %label.col-sm-2.control-label.required Age
          .col-sm-10
            %input.age.form-control(placeholder='Your age' type='text')/
        .form-group
          %label.col-sm-2.control-label.required Symptoms
          .col-sm-10
            %select.symptoms(multiple)
              - @symptoms.each do |symptom|
                %option{name: symptom.name, value: symptom.name}= symptom.name
        .form-group
          %label.col-sm-2.control-label Allergies
          .col-sm-10
            %select.allergies(multiple)
              - @allergies.each do |allergy|
                %option{name: allergy.name, value: allergy.name}= allergy.name
      %hr
      .suggestion
        .col-sm-6
          Drugs
          %ul.drugs.list-group

        .col-sm-6
          Doctors
          %ul.doctors.list-group
~~~

**app/assets/javascripts/application.js**

~~~javascript
// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree .

window.onload = function(){
    if(navigator.geolocation) navigator.geolocation.getCurrentPosition(handleGetCurrentPosition);
};

function handleGetCurrentPosition(location){
    window.latitude     = location.coords.latitude;
    window.longitude    = location.coords.longitude;
}

$(document).ready(function(){
    var adviseDrug = function(symptoms, age, allergies){
        $.getJSON('/drugs', {"symptoms": symptoms, "allergies": allergies, age: age, latitude: window.latitude, longitude: window.longitude}).done(function(json){
            $(".suggestion .drugs").empty();
            $.each(json, function(key, value){
                $(".suggestion .drugs").append('<li class="list-group-item">' + value + '</li>');
            });
        });
    };

    var adviseDoctor = function(symptoms, age, allergies){
        $.getJSON('/doctors', {"symptoms": symptoms, "allergies": allergies, age: age, latitude: window.latitude, longitude: window.longitude}).done(function(json){
            $(".suggestion .doctors").empty();
            $.each(json, function(key, value){
                $(".suggestion .doctors").append('<li class="list-group-item"><span class="badge">' + value + ' km</span>' + key + '</li>');
            });
        });
    };

    var updateSuggestions = function(element){
        var advisor     = $(element).parents('.advisor');
        var symptoms    = advisor.find('.symptoms').val();
        var allergies   = advisor.find('.allergies').val();
        var age         = advisor.find('.age').val();
        adviseDrug(symptoms, age, allergies);
        adviseDoctor(symptoms, age, allergies);
    };

    var multiselectOptions = {
        numberDisplayed: 5,
        buttonWidth: '400px',
        onChange: function(option, checked, select) {
            updateSuggestions(option);
        }
    };

    $('.advisor select.symptoms').multiselect($.extend({}, multiselectOptions, {
        nonSelectedText: 'Select symptoms'
    }));

    $('.advisor select.allergies').multiselect($.extend({}, multiselectOptions, {
        nonSelectedText: 'Select allergies'
    }));

    $('.advisor input.age').blur(function(){
        updateSuggestions(this);
    });

    $('.advisor input.age').keypress(function(e) {
        if(e.which == 13) {
            updateSuggestions(this);
            e.preventDefault();
        }
    });
});
~~~
