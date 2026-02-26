Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Devise routes — outside namespace to keep scope as :user
  devise_for :users,
    path: "api/v1/users",
    controllers: {
      sessions: "api/v1/sessions",
      registrations: "api/v1/registrations"
    },
    skip: [ :passwords ],
    defaults: { format: :json }

  # Password reset (standalone, not Devise controller)
  post "api/v1/users/password", to: "api/v1/passwords#create"
  put  "api/v1/users/password", to: "api/v1/passwords#update"
  patch "api/v1/users/password", to: "api/v1/passwords#update"

  namespace :api do
    namespace :v1 do
      # Dashboard
      get "dashboard", to: "dashboard#index"

      # Health check (API-level)
      get "health", to: "health#show"

      # Profile (current user)
      resource :profile, only: [ :show, :update ] do
        patch :change_password, on: :member
      end

      # Tenant settings (current tenant only)
      resource :tenant, only: [ :show, :update ]

      # User management (admin)
      resources :users, only: [ :index, :show, :create, :update ] do
        collection do
          post :bulk_update_status
        end
        member do
          post :resend_invitation
        end
      end

      # Cases with nested resources
      resources :cases do
        collection do
          post :bulk_update_status
        end
        member do
          post :start_analysis
          get :analysis_status
          patch :assign_attorney
          patch :mark_reviewed
          patch :mark_responded
          post :archive
          post :reopen
          post :export
          get :export
          get :activity
        end

        resources :rfe_documents, only: [ :index, :show, :create, :destroy ]

        resources :rfe_sections, only: [ :index, :show, :update ] do
          member do
            post :reclassify
          end
        end

        resources :evidence_checklists, only: [ :index, :update ] do
          member do
            patch :toggle_collected
          end
        end

        resources :draft_responses, only: [ :index, :show, :update ] do
          collection do
            post :generate_all
          end
          member do
            patch :approve
            post :regenerate
          end
        end

        resources :exhibits do
          collection do
            patch :reorder
          end
        end

        resources :comments, only: [:index, :create, :update, :destroy]
      end

      # Knowledge base
      resources :knowledge_docs do
        collection do
          post :bulk_create
        end
      end

      # Knowledge semantic search
      get "knowledge/search", to: "knowledge_search#search"

      # SSO / OAuth callbacks
      get "auth/:provider/callback", to: "omniauth#callback"
      post "auth/:provider/callback", to: "omniauth#callback"
      get "auth/failure", to: "omniauth#failure"

      # Two-Factor Authentication
      resource :two_factor, controller: "two_factor", only: [] do
        post :setup, on: :collection
        post :verify, on: :collection
        delete :disable, on: :collection, path: ""
        post :validate, on: :collection
      end

      # Global search
      get "search", to: "search#index"

      # Feature flags
      resources :feature_flags, only: [ :index, :create, :update, :destroy ] do
        collection do
          get :manage
        end
      end

      # Backups (admin only)
      resources :backups, only: [ :index, :create, :destroy ] do
        member do
          get :download
        end
      end

      # Audit logs (admin only)
      resources :audit_logs, only: [ :index ] do
        collection do
          get :export
        end
      end

      # Super Admin panel
      namespace :admin do
        get "dashboard", to: "dashboard#index"

        resources :tenants do
          member do
            patch :change_status
            patch :change_plan
          end
          resources :users, only: [ :index, :show, :create, :update, :destroy ]
        end
      end
    end
  end
end
