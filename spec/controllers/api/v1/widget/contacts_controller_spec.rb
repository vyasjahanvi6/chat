require 'rails_helper'

RSpec.describe '/api/v1/widget/contacts', type: :request do
  let(:account) { create(:account) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: web_widget.inbox) }
  let(:payload) { { source_id: contact_inbox.source_id, inbox_id: web_widget.inbox.id } }
  let(:token) { ::Widget::TokenService.new(payload: payload).generate_token }

  describe 'PATCH /api/v1/widget/contact' do
    let(:params) { { website_token: web_widget.website_token, identifier: 'test' } }

    context 'with invalid website token' do
      it 'returns unauthorized' do
        patch '/api/v1/widget/contact', params: { website_token: '' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with correct website token' do
      let(:identify_action) { double }

      before do
        allow(ContactIdentifyAction).to receive(:new).and_return(identify_action)
        allow(identify_action).to receive(:perform)
      end

      it 'calls contact identify' do
        patch '/api/v1/widget/contact',
              params: params,
              headers: { 'X-Auth-Token' => token },
              as: :json

        expect(response).to have_http_status(:success)
        expected_params = { contact: contact, params: params }
        expect(ContactIdentifyAction).to have_received(:new).with(expected_params)
        expect(identify_action).to have_received(:perform)
      end
    end
  end
end
