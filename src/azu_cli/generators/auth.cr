require "teeplate"

module AzuCLI
  module Generate
    # Authentication setup generator
    class Auth < Teeplate::FileTree
      directory "#{__DIR__}/../templates/auth"
      OUTPUT_DIR = "."

      property project : String
      property strategy : String # jwt, session, oauth
      property user_model : String

      def initialize(@project : String, @strategy : String = "jwt", @user_model : String = "User")
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

      # Generate password hashing method
      def password_hash_method : String
        <<-METHOD
          # Hash password using bcrypt
          def hash_password(password : String) : String
            Crypto::Bcrypt::Password.create(password).to_s
          end

          # Verify password against hash
          def verify_password(password : String, hash : String) : Bool
            Crypto::Bcrypt::Password.new(hash).verify(password)
          end
        METHOD
      end

      # Generate JWT methods
      def jwt_methods : String
        return "" unless using_jwt?

        <<-METHODS
          # Generate JWT token
          def generate_token(user_id : Int64, expiry : Time::Span = 24.hours) : String
            payload = {
              "user_id" => user_id,
              "exp" => (Time.utc + expiry).to_unix
            }
            JWT.encode(payload, jwt_secret, JWT::Algorithm::HS256)
          end

          # Verify JWT token
          def verify_token(token : String) : Int64?
            payload, _header = JWT.decode(token, jwt_secret, JWT::Algorithm::HS256)
            payload["user_id"].as_i64
          rescue
            nil
          end

          private def jwt_secret : String
            ENV["JWT_SECRET"]? || raise "JWT_SECRET not set"
          end
        METHODS
      end

      # Get required dependencies
      def dependencies : Array(String)
        deps = ["crypto/bcrypt"]
        deps << "jwt" if using_jwt?
        deps
      end

      # Get migration content
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
            column :created_at, Time, default: "NOW()"
            column :updated_at, Time, default: "NOW()"

            add_index :users, :email
            add_index :users, :role
          end
        MIGRATION
      end
    end
  end
end

