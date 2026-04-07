SolidQueueLite::Engine.routes.draw do
  root to: "dashboards#show"
  resource :dashboard, only: [ :show ], controller: :dashboards

  resources :jobs, only: [ :index, :show ] do
    collection do
      post :bulk_retry
      post :bulk_discard
    end

    member do
      post :retry
      post :discard
    end
  end

  resources :processes, only: [ :index ] do
    collection do
      post :prune
    end
  end

  resources :queues, only: [ :index ], controller: :queues do
    collection do
      post :pause
      post :resume
      post :clear
    end
  end
end
