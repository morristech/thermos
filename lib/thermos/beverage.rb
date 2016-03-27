class Thermos::Beverage
  attr_reader :key, :model, :deps, :action, :lookup_key

  def initialize(key:, model:, deps:, action:, lookup_key: nil)
    @key = key
    @model = model
    @lookup_key = lookup_key || :id
    @deps = deps.map do |dep|
      Thermos::Dependency.new(model: model, association: dep)
    end
    @action = action

    set_observers
  end

  def deps_for_class(klass)
    @deps.select do |dep|
      dep.klass == klass.name
    end
  end

  private

  def set_observers
    observe(@model)
    @deps.each { |dep| observe(dep.klass) }
  end

  def observe(model)
    model.include(Thermos::Notifier) unless model.included_modules.include?(Thermos::Notifier)
  end
end