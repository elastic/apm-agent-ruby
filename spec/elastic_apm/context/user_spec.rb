# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Context::User do
    it 'sets values from passed object' do
      PossiblyUser = Struct.new(:id, :email, :username)
      record = PossiblyUser.new(1, 'a@a', 'monkeyface')

      user = described_class.new(Config.new, record)
      expect(user.to_h).to eq(
        id: 1,
        email: 'a@a',
        username: 'monkeyface'
      )
    end

    it "doesn't explode with missing methods" do
      expect do
        user = described_class.new(Config.new, Object.new)
        expect(user.to_h).to eq(id: nil, email: nil, username: nil)
      end.to_not raise_exception
    end
  end
end
