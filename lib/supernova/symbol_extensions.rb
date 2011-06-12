Symbol.class_eval do
  [:not, :gt, :gte, :lt, :lte, :ne].each do |method|
    define_method(method) do
      Supernova::Condition.new(self, method)
    end
  end
end