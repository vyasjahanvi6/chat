# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Confirmation Instructions', type: :mailer do
  describe :notify do
    let(:account) { create(:account) }
    let(:confirmable_user) { create(:user, inviter: inviter_val, account: account) }
    let(:inviter_val) { nil }
    let(:mail) { Devise::Mailer.confirmation_instructions(confirmable_user, nil, {}) }

    it 'has the correct header data' do
      expect(mail.reply_to).to contain_exactly('accounts@chatwoot.com')
      expect(mail.to).to contain_exactly(confirmable_user.email)
      expect(mail.subject).to eq('Confirmation Instructions')
    end

    it 'uses the user\'s name' do
      expect(mail.body).to match("Welcome, #{CGI.escapeHTML(confirmable_user.name)}!")
    end

    it 'does not refer to the inviter and their account' do
      expect(mail.body).to_not match('has invited you to try out Chatwoot!')
    end

    context 'when there is an inviter' do
      let(:inviter_val) { create(:user, :administrator, skip_confirmation: true, account: account) }

      it 'refers to the inviter and their account' do
        expect(mail.body).to match(
          "#{CGI.escapeHTML(inviter_val.name)}, with #{CGI.escapeHTML(account.name)}, has invited you to try out Chatwoot!"
        )
      end
    end
  end
end
