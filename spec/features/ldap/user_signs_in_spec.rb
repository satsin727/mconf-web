# This file is part of Mconf-Web, a web application that provides access
# to the Mconf webconferencing system. Copyright (C) 2010-2015 Mconf.
#
# This file is licensed under the Affero General Public License version
# 3 or later. See the LICENSE file.

require 'spec_helper'
require 'support/feature_helpers'

describe 'User signs in via ldap', ldap: true do
  subject { page }
  before(:all) {
    @ldap_attrs = { username: 'passoca', password: 'passocaword', email: 'passoca@amendo.in' }

    Mconf::LdapServerRunner.add_user @ldap_attrs[:username], @ldap_attrs[:password], @ldap_attrs[:email]
    Mconf::LdapServerRunner.start
  }
  after(:all) { Mconf::LdapServerRunner.stop }

  before { enable_ldap }

  context 'for the first time' do
    before {
      visit new_user_session_path
    }

    context 'and the user is registered in the ldap server' do
      before { sign_in_with @ldap_attrs[:username], @ldap_attrs[:password] }

      it { current_path.should eq(my_home_path) }
      it { should have_content @ldap_attrs[:username] }
      it { should have_content @ldap_attrs[:email] }
    end

    context 'and the user is already registered for the site' do

      context 'and enters valid credentials' do
        let(:user) { FactoryGirl.create(:user) }
        before { sign_in_with user.username, user.password }

        it { current_path.should eq(my_home_path) }
        it { should have_content user._full_name }
        it { should have_content user.email }
      end

      context "the user's account is disabled" do
        let(:user) { LdapToken.last.user }
        before {
          # create the LDAP token, log out
          sign_in_with @ldap_attrs[:username], @ldap_attrs[:password]
          logout_user

          user.disable
          sign_in_with @ldap_attrs[:username], @ldap_attrs[:password]
        }

        it { has_failure_message }
        it { current_path.should eq(new_user_session_path) }
      end

      context "the site requires approval" do
        before {
          Site.current.update_attributes require_registration_approval: true
          sign_in_with @ldap_attrs[:username], @ldap_attrs[:password]
        }

        it { has_failure_message t('devise.failure.user.not_approved') }
        it { current_path.should eq(my_approval_pending_path) }
      end
    end

    context "creating the user's account" do
      context "successfully" do
        before {
          expect {
            sign_in_with @ldap_attrs[:username], @ldap_attrs[:password]
          }.to change{ User.count }
        }

        it { current_path.should eq(my_home_path) }
        it("creates a LdapToken") { LdapToken.count.should be(1) }
      end

      context "but encountering a server error" do

      end

      skip "and there's a conflict on the user's username with another user" do
        before {
          FactoryGirl.create(:user, username: @ldap_attrs[:_full_name].parameterize)
          expect {
            click_button t('sessions.login_form.login')
          }.not_to change{ User.count }
        }

        it { current_path.should eq(new_user_session_path) }
        it { has_failure_message "Username has already been taken" }
        it("doesn't create a LdapToken") { LdapToken.count.should be(0) }
        it("doesn't send emails") { UserMailer.should have_queue_size_of(0) }
      end

      skip "and there's a conflict on the user's username with a space" do
        before {
          FactoryGirl.create(:space, permalink: @ldap_attrs[:_full_name].parameterize)
          expect {
            click_button t('sessions.login_form.login')
          }.not_to change{ User.count }
        }

        it { current_path.should eq(new_user_session_path) }
        it { has_failure_message "Username has already been taken" }
        it("doesn't create a LdapToken") { LdapToken.count.should be(0) }
        it("doesn't send emails") { UserMailer.should have_queue_size_of(0) }
      end

      skip "and there's a conflict on the user's username with a room" do
        before {
          FactoryGirl.create(:bigbluebutton_room, param: @ldap_attrs[:_full_name].parameterize)
          expect {
            click_button t('sessions.login_form.login')
          }.not_to change{ User.count }
        }

        it { current_path.should eq(new_user_session_path) }
        it { has_failure_message "Username has already been taken" }
        it("doesn't create a LdapToken") { LdapToken.count.should be(0) }
        it("doesn't send emails") { UserMailer.should have_queue_size_of(0) }
      end

      skip "and there's a conflict in the user's email" do
        before {
          FactoryGirl.create(:user, email: @ldap_attrs[:email])
          expect {
            click_button t('sessions.login_form.login')
          }.not_to change{ User.count }
        }

        it { current_path.should eq(new_user_session_path) }
        it { has_failure_message }
        it("doesn't create a LdapToken") { LdapToken.count.should be(0) }
        it("doesn't send emails") { UserMailer.should have_queue_size_of(0) }
      end
    end
  end

end
