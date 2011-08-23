Symbol.class_eval do
  [:not, :gt, :gte, :lt, :lte, :ne, :nin, :in].each do |method|
    define_method(method) do
      Supernova::Condition.new(self, method)
    end
  end
end