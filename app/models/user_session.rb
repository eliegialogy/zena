class UserSession < Authlogic::Session::Base
  self.find_by_login_method = :find_allowed_user_by_login

end