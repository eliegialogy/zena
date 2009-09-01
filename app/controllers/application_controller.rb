class ApplicationController < ActionController::Base
  
  include Zena::Use::Authentification::ControllerMethods
  include Zena::Use::ErrorRendering::ControllerMethods
  include Zena::Use::I18n::ControllerMethods
  include Zena::Use::Refactor::ControllerMethods
  include Zena::Use::Rendering::ControllerMethods
  include Zena::Use::Urls::ControllerMethods
  include Zena::Use::Zafu::ControllerMethods
  
  helper  Zena::Acts::Secure
  helper  Zena::Use::Ajax::ViewMethods
  helper  Zena::Use::Calendar::ViewMethods
  helper  Zena::Use::ErrorRendering::ViewMethods
  helper  Zena::Use::HtmlTags::ViewMethods
  helper  Zena::Use::I18n::ViewMethods
  helper  Zena::Use::Refactor::ViewMethods
  helper  Zena::Use::Urls::ViewMethods
  helper  Zena::Use::Zafu::ViewMethods
  helper  Zena::Use::Zazen::ViewMethods
  
  layout false
  
end

Bricks::Patcher.apply_patches