require 'test_helper'

class SubscriptionsControllerTest < ActionController::TestCase

  setup do
    @user = users(:ben)
  end

  test "should get index" do
    login_as @user
    get :index, format: :xml
    assert_response :success
  end

  test "should create subscription" do
    html_url = "www.example.com/index.html"
    feed_url = "http://www.example.com/atom.xml"
    stub_request_file('index.html', html_url)
    stub_request_file('atom.xml', feed_url)

    feed = Feed.create(feed_url: feed_url)

    verifier = ActiveSupport::MessageVerifier.new(Feedbin::Application.config.secret_key_base)
    valid_feed_ids = verifier.generate([feed.id])

    params = {
      valid_feed_ids: valid_feed_ids,
      feeds: {
        feed.id => {
          title: "title",
          tags: "Design",
          subscribe: "1"
        }
      }
    }
    login_as @user
    assert_difference "Subscription.count", +1 do
      post :create, params: params, xhr: true
      assert_response :success
    end
  end

  test "should destroy subscription" do
    login_as @user
    subscription = @user.subscriptions.first
    assert_difference "Subscription.count", -1 do
      delete :destroy, params: {id: subscription}, xhr: true
      assert_response :success
    end
  end

  test "should destroy subscription settings" do
    login_as @user
    subscription = @user.subscriptions.first
    assert_difference "Subscription.count", -1 do
      delete :settings_destroy, params: {id: subscription}, xhr: true
      assert_redirected_to settings_feeds_url
    end
  end

  test "should destroy subscription with feed id" do
    login_as @user
    subscription = @user.subscriptions.first
    assert_difference "Subscription.count", -1 do
      delete :feed_destroy, params: {id: subscription.feed_id}, xhr: true
      assert_response :success
    end
  end

  test "should destroy multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    assert_difference "Subscription.count", -ids.length do
      post :update_multiple, params: {operation: 'unsubscribe', subscription_ids: ids}
      assert_redirected_to settings_feeds_url
    end
  end

  test "should show_updates multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    post :update_multiple, params: {operation: 'show_updates', subscription_ids: ids}
    assert_equal ids.sort, @user.subscriptions.where(show_updates: true).pluck(:id).sort
    assert_redirected_to settings_feeds_url
  end

  test "should hide_updates multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    post :update_multiple, params: {operation: 'hide_updates', subscription_ids: ids}
    assert_equal ids.sort, @user.subscriptions.where(show_updates: false).pluck(:id).sort
    assert_redirected_to settings_feeds_url
  end

  test "should mute multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    post :update_multiple, params: {operation: 'mute', subscription_ids: ids}
    assert_equal ids.sort, @user.subscriptions.where(muted: true).pluck(:id).sort
    assert_redirected_to settings_feeds_url
  end

  test "should unmute multiple subscriptions" do
    login_as @user
    ids = @user.subscriptions.pluck(:id)
    post :update_multiple, params: {operation: 'unmute', subscription_ids: ids}
    assert_equal ids.sort, @user.subscriptions.where(muted: false).pluck(:id).sort
    assert_redirected_to settings_feeds_url
  end

  test "should get edit" do
    login_as @user
    get :edit, params: {id: @user.subscriptions.first}
    assert_response :success
  end

  test "should update subscription" do
    login_as @user
    subscription = @user.subscriptions.first

    attributes = {muted: true, show_updates: false}
    patch :update, params: {id: subscription, subscription: attributes}, xhr: true

    assert_response :success
    attributes.each do |attribute, value|
      assert_equal(value, subscription.reload.send(attribute))
    end
  end

  test "should refresh favicon" do
    login_as @user
    subscription = @user.subscriptions.first

    assert_difference "FaviconFetcher.jobs.size", +1 do
      post :refresh_favicon, params: {id: subscription}, xhr: true
      assert_response :success
    end
  end

end