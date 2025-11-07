require "teeplate"
require "cadmium_inflector"

module AzuCLI
  module Generate
    # Authentication setup generator with Authly integration
    class Auth < Teeplate::FileTree
      directory "#{__DIR__}/../templates/auth"
      OUTPUT_DIR = "."

      property project : String
      property strategy : String # jwt, session, oauth, authly
      property user_model : String
      property enable_rbac : Bool
      property enable_csrf : Bool
      property enable_oauth_providers : Array(String)

      def initialize(@project : String, @strategy : String = "authly", @user_model : String = "User", @enable_rbac : Bool = true, @enable_csrf : Bool = true, @enable_oauth_providers : Array(String) = ["google", "github"])
      end

      # Check if using JWT
      def using_jwt? : Bool
        @strategy == "jwt"
      end

      # Check if using session
      def using_session? : Bool
        @strategy == "session"
      end

      # Check if using OAuth
      def using_oauth? : Bool
        @strategy == "oauth"
      end

      # Check if using Authly
      def using_authly? : Bool
        @strategy == "authly"
      end

      # Check if RBAC is enabled
      def rbac_enabled? : Bool
        @enable_rbac
      end

      # Check if CSRF protection is enabled
      def csrf_enabled? : Bool
        @enable_csrf
      end

      # Get enabled OAuth providers
      def oauth_providers : Array(String)
        @enable_oauth_providers
      end

      # Check if Google OAuth is enabled
      def google_oauth_enabled? : Bool
        @enable_oauth_providers.includes?("google")
      end

      # Check if GitHub OAuth is enabled
      def github_oauth_enabled? : Bool
        @enable_oauth_providers.includes?("github")
      end

      # User model helper methods
      def user_model_class : String
        @user_model
      end

      def user_model_singular : String
        @user_model.downcase
      end

      def user_model_plural : String
        @user_model.downcase.pluralize
      end

      def user_model_table : String
        user_model_plural
      end

      # Dynamic timestamp for migrations/templates (Int64)
      @timestamp : Int64 = Time.utc.to_unix

      def timestamp : Int64
        @timestamp
      end

      # Infer project mode based on presence of pages directory
      def api_mode? : Bool
        !Dir.exists?(File.join(OUTPUT_DIR, "src/pages"))
      end

      def web_mode? : Bool
        !api_mode?
      end

      # Generate password hashing method with enhanced security
      def password_hash_method : String
        <<-METHOD
          # Hash password using bcrypt with high cost factor
          def hash_password(password : String) : String
            Crypto::Bcrypt::Password.create(password, cost: 14).to_s
          end

          # Verify password against hash
          def verify_password(password : String, hash : String) : Bool
            Crypto::Bcrypt::Password.new(hash).verify(password)
          end

          # Generate secure random password
          def generate_secure_password(length : Int32 = 16) : String
            chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
            password = String.build(length) do |str|
              length.times do
                str << chars[Random.rand(chars.size)]
              end
            end
            password
          end
        METHOD
      end

      # Generate enhanced JWT methods with security improvements
      def jwt_methods : String
        return "" unless using_jwt? || using_authly?

        <<-METHODS
          # Generate JWT token with enhanced security
          def generate_token(user_id : Int64, role : String = "user", expiry : Time::Span = 15.minutes) : String
            now = Time.utc
            payload = {
              "sub" => user_id.to_s,           # Subject (user ID)
              "iat" => now.to_unix,            # Issued at
              "exp" => (now + expiry).to_unix, # Expiration
              "nbf" => now.to_unix,            # Not before
              "role" => role,                  # User role
              "iss" => jwt_issuer,             # Issuer
              "aud" => jwt_audience,           # Audience
              "jti" => generate_jti            # JWT ID (unique)
            }
            JWT.encode(payload, jwt_secret, JWT::Algorithm::HS256)
          end

          # Generate refresh token
          def generate_refresh_token(user_id : Int64) : String
            payload = {
              "sub" => user_id.to_s,
              "type" => "refresh",
              "iat" => Time.utc.to_unix,
              "exp" => (Time.utc + 7.days).to_unix,
              "jti" => generate_jti
            }
            JWT.encode(payload, jwt_refresh_secret, JWT::Algorithm::HS256)
          end

          # Verify JWT token with comprehensive validation
          def verify_token(token : String) : Hash(String, JSON::Any)?
            payload, header = JWT.decode(token, jwt_secret, JWT::Algorithm::HS256)

            # Validate standard claims
            validate_token_claims(payload)

            payload
          rescue JWT::Error
            nil
          end

          # Verify refresh token
          def verify_refresh_token(token : String) : Hash(String, JSON::Any)?
            payload, header = JWT.decode(token, jwt_refresh_secret, JWT::Algorithm::HS256)

            # Validate it's a refresh token
            return nil unless payload["type"]? == "refresh"

            validate_token_claims(payload)
            payload
          rescue JWT::Error
            nil
          end

          # Generate unique JWT ID
          def generate_jti : String
            UUID.random.to_s
          end

          # Validate token claims
          private def validate_token_claims(payload : Hash(String, JSON::Any)) : Bool
            # Check issuer
            return false unless payload["iss"]? == jwt_issuer

            # Check audience
            return false unless payload["aud"]? == jwt_audience

            # Check expiration
            exp = payload["exp"]?.try(&.as_i)
            return false unless exp && Time.unix(exp) > Time.utc

            # Check not before
            nbf = payload["nbf"]?.try(&.as_i)
            return false unless nbf && Time.unix(nbf) <= Time.utc

            true
          end

          # JWT configuration
          private def jwt_secret : String
            ENV["JWT_SECRET"]? || raise "JWT_SECRET environment variable not set"
          end

          private def jwt_refresh_secret : String
            ENV["JWT_REFRESH_SECRET"]? || raise "JWT_REFRESH_SECRET environment variable not set"
          end

          private def jwt_issuer : String
            ENV["JWT_ISSUER"]? || "#{@project.downcase}-api"
          end

          private def jwt_audience : String
            ENV["JWT_AUDIENCE"]? || "#{@project.downcase}-client"
          end
        METHODS
      end

      # Get required dependencies
      def dependencies : Array(String)
        deps = ["crypto/bcrypt", "uuid"]

        # Add JWT support
        deps << "jwt" if using_jwt? || using_authly?

        # Add Authly OAuth2 library
        deps << "authly" if using_authly?

        # Add secure random for session-based auth
        deps << "secure_random" if using_session?

        # Add CSRF protection
        deps << "openssl" if csrf_enabled?
        deps << "base64" if csrf_enabled?

        deps
      end

      # Get migration content with enhanced security and RBAC
      def user_migration : String
        <<-MIGRATION
          schema.create :users do
            primary :id, Int64, auto: true
            column :email, String, size: 255, unique: true, null: false
            column :password_hash, String, size: 255, null: false
            column :name, String, size: 255
            column :role, String, size: 50, default: "user"
            column :confirmed_at, Time
            column :locked_at, Time
            column :failed_login_attempts, Int32, default: 0
            column :last_login_at, Time
            column :password_changed_at, Time
            column :two_factor_enabled, Bool, default: false
            column :two_factor_secret, String, size: 255
            column :recovery_codes, String, size: 1000
            column :created_at, Time, default: "NOW()"
            column :updated_at, Time, default: "NOW()"

            add_index :users, :email
            add_index :users, :role
            add_index :users, :confirmed_at
            add_index :users, :locked_at
          end

          <%- if rbac_enabled? %>
          # Roles table for RBAC
          schema.create :roles do
            primary :id, Int64, auto: true
            column :name, String, size: 100, unique: true, null: false
            column :description, String, size: 500
            column :permissions, String, size: 2000  # JSON array of permissions
            column :created_at, Time, default: "NOW()"
            column :updated_at, Time, default: "NOW()"

            add_index :roles, :name
          end

          # User roles junction table
          schema.create :user_roles do
            primary :id, Int64, auto: true
            column :user_id, Int64, null: false
            column :role_id, Int64, null: false
            column :assigned_at, Time, default: "NOW()"
            column :assigned_by, Int64

            add_index :user_roles, :user_id
            add_index :user_roles, :role_id
            add_index :user_roles, [:user_id, :role_id], unique: true
          end

          # Permissions table
          schema.create :permissions do
            primary :id, Int64, auto: true
            column :name, String, size: 100, unique: true, null: false
            column :description, String, size: 500
            column :resource, String, size: 100
            column :action, String, size: 50
            column :created_at, Time, default: "NOW()"

            add_index :permissions, :name
            add_index :permissions, :resource
            add_index :permissions, [:resource, :action], unique: true
          end

          # Role permissions junction table
          schema.create :role_permissions do
            primary :id, Int64, auto: true
            column :role_id, Int64, null: false
            column :permission_id, Int64, null: false
            column :created_at, Time, default: "NOW()"

            add_index :role_permissions, :role_id
            add_index :role_permissions, :permission_id
            add_index :role_permissions, [:role_id, :permission_id], unique: true
          end
          <%- end %>

          <%- if using_authly? %>
          # OAuth applications table for Authly
          schema.create :oauth_applications do
            primary :id, Int64, auto: true
            column :name, String, size: 255, null: false
            column :client_id, String, size: 255, unique: true, null: false
            column :client_secret, String, size: 255, null: false
            column :redirect_uri, String, size: 1000
            column :scopes, String, size: 500
            column :confidential, Bool, default: true
            column :created_at, Time, default: "NOW()"
            column :updated_at, Time, default: "NOW()"

            add_index :oauth_applications, :client_id
          end

          # OAuth access tokens table
          schema.create :oauth_access_tokens do
            primary :id, Int64, auto: true
            column :application_id, Int64, null: false
            column :resource_owner_id, Int64, null: false
            column :token, String, size: 255, unique: true, null: false
            column :refresh_token, String, size: 255, unique: true
            column :expires_in, Int32
            column :scopes, String, size: 500
            column :created_at, Time, default: "NOW()"
            column :revoked_at, Time

            add_index :oauth_access_tokens, :token
            add_index :oauth_access_tokens, :refresh_token
            add_index :oauth_access_tokens, :application_id
            add_index :oauth_access_tokens, :resource_owner_id
          end
          <%- end %>
        MIGRATION
      end
    end
  end
end
