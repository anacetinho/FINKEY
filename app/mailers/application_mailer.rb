class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name(ENV.fetch("EMAIL_SENDER", "sender@finkey.local"), "FinKey")
  layout "mailer"
end
