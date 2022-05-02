# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get '/create_event', to: 'messages#create_event'
  get '/create_event_replies', to: 'messages#create_event_replies'
  get '/create_event_details_replies', to: 'messages#create_event_details_replies'
  get '/event_decision_reply', to: 'messages#event_decision_reply'

  get '/catch_all', to: 'catch_all#handle'
end