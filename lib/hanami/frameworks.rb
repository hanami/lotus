require 'hanami/utils'
require 'hanami/validations'
require 'hanami/router'
require 'hanami/view'
require 'hanami/controller'
require 'hanami/action/glue'
require 'hanami/action/csrf_protection'
require 'hanami/mailer'
require 'hanami/assets'

Hanami::Controller::MissingSessionError.class_eval do
  def initialize(session_method)
    super("To use `#{session_method}', please enable sessions for the current app.")
  end
end
