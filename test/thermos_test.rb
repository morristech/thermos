require 'test_helper'

class ThermosTest < ActiveSupport::TestCase
  ActiveSupport.test_order = :random
  self.use_transactional_fixtures = true

  def teardown
    Thermos.empty
    Rails.cache.clear
  end

  test "keeps the cache warm using fill / drink" do
    mock = Minitest::Mock.new

    Thermos.fill(key: "key", model: Category) do |id|
      mock.call(id)
    end

    mock.expect(:call, 1, [1])
    assert_equal 1, Thermos.drink(key: "key", id: 1)
    mock.verify

    mock.expect(:call, 2, [1])
    assert_equal 1, Thermos.drink(key: "key", id: 1)
    assert_raises(MockExpectationError) { mock.verify }
  end

  test "keeps the cache warm using keep_warm" do
    mock = Minitest::Mock.new

    mock.expect(:call, 1, [1])
    response = Thermos.keep_warm(key: "key", model: Category, id: 1) do |id|
      mock.call(id)
    end
    assert_equal 1, response
    mock.verify

    mock.expect(:call, 2, [1])
    response = Thermos.keep_warm(key: "key", model: Category, id: 1) do |id|
      mock.call(id)
    end
    assert_equal 1, response
    assert_raises(MockExpectationError) { mock.verify }
  end

  test "rebuilds the cache on primary model change" do
    mock = Minitest::Mock.new
    category = categories(:baseball)

    Thermos.fill(key: "key", model: Category) do |id|
      mock.call(id)
    end

    mock.expect(:call, 1, [category.id])
    assert_equal 1, Thermos.drink(key: "key", id: category.id)
    mock.verify

    mock.expect(:call, 2, [category.id])
    category.update!(name: "foo")
    mock.verify

    mock.expect(:call, 3, [category.id])
    assert_equal 2, Thermos.drink(key: "key", id: category.id)
    assert_raises(MockExpectationError) { mock.verify }
  end

  test "rebuilds the cache on has_many model change" do
    mock = Minitest::Mock.new
    category = categories(:baseball)
    category_item = category_items(:baseball_glove)

    Thermos.fill(key: "key", model: Category, deps: [:category_items]) do |id|
      mock.call(id)
    end

    mock.expect(:call, 1, [category.id])
    assert_equal 1, Thermos.drink(key: "key", id: category.id)
    mock.verify

    mock.expect(:call, 2, [category.id])
    category_item.update!(name: "foo")
    mock.verify

    mock.expect(:call, 3, [category.id])
    assert_equal 2, Thermos.drink(key: "key", id: category.id)
    assert_raises(MockExpectationError) { mock.verify }
  end

  test "rebuilds the cache on belongs_to model change" do
    mock = Minitest::Mock.new
    category = categories(:baseball)
    store = stores(:sports)

    Thermos.fill(key: "key", model: Category, deps: [:store]) do |id|
      mock.call(id)
    end

    mock.expect(:call, 1, [category.id])
    assert_equal 1, Thermos.drink(key: "key", id: category.id)
    mock.verify

    mock.expect(:call, 2, [category.id])
    store.update!(name: "foo")
    mock.verify

    mock.expect(:call, 3, [category.id])
    assert_equal 2, Thermos.drink(key: "key", id: category.id)
    assert_raises(MockExpectationError) { mock.verify }
  end

  test "rebuilds the cache on has_many through model change" do
    mock = Minitest::Mock.new
    category = categories(:baseball)
    product = products(:glove)

    Thermos.fill(key: "key", model: Category, deps: [:products]) do |id|
      mock.call(id)
    end

    mock.expect(:call, 1, [category.id])
    assert_equal 1, Thermos.drink(key: "key", id: category.id)
    mock.verify

    mock.expect(:call, 2, [category.id])
    product.update!(name: "foo")
    mock.verify

    mock.expect(:call, 3, [category.id])
    assert_equal 2, Thermos.drink(key: "key", id: category.id)
    assert_raises(MockExpectationError) { mock.verify }
  end

  test "only rebuilds cache for stated dependencies, even if another cache has an associated model of the primary" do
    category_mock = Minitest::Mock.new
    product_mock = Minitest::Mock.new
    category = categories(:baseball)
    product = products(:glove)

    Thermos.fill(key: "category_key", model: Category) do |id|
      category_mock.call(id)
    end

    Thermos.fill(key: "product_key", model: Product) do |id|
      product_mock.call(id)
    end

    category_mock.expect(:call, 2, [category.id])
    product_mock.expect(:call, 2, [product.id])
    product.update!(name: "foo")
    assert_raises(MockExpectationError) { category_mock.verify }
    product_mock.verify
  end

  test "accepts and can rebuild off of an id other than the 'id'" do
    mock = Minitest::Mock.new
    category = categories(:baseball)
    product = products(:glove)

    Thermos.fill(key: "key", model: Category, deps: [:products], lookup_key: :name) do |id|
      mock.call(id)
    end

    mock.expect(:call, 1, [category.name])
    assert_equal 1, Thermos.drink(key: "key", id: category.name)
    mock.verify

    mock.expect(:call, 2, ["foo"])
    category.update!(name: "foo")
    mock.verify

    mock.expect(:call, 3, [category.name])
    product.update!(name: "foo")
    mock.verify

    mock.expect(:call, 4, [category.name])
    assert_equal 3, Thermos.drink(key: "key", id: category.name)
    assert_raises(MockExpectationError) { mock.verify }
  end
end
