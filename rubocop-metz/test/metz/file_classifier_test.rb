# frozen_string_literal: true

require_relative "../test_helper"

class MetzFileClassifierTest < Minitest::Test
  def test_resolves_to_a_module_not_a_class
    assert_kind_of Module, Metz::FileClassifier
    refute_kind_of Class, Metz::FileClassifier
  end

  def test_responds_to_predicate_api
    %i[controller? view? model?].each do |predicate|
      assert_respond_to Metz::FileClassifier, predicate
    end
  end

  def test_predicates_return_strict_booleans
    boolean_values = [true, false]

    %i[controller? view? model?].each do |predicate|
      hit = Metz::FileClassifier.public_send(predicate, "app/controllers/x_controller.rb")
      miss = Metz::FileClassifier.public_send(predicate, "lib/foo.txt")

      assert_includes boolean_values, hit, "#{predicate} returned non-boolean #{hit.inspect}"
      assert_includes boolean_values, miss, "#{predicate} returned non-boolean #{miss.inspect}"
    end
  end

  def test_controller_predicate_matches_only_controllers
    %w[
      app/controllers/users_controller.rb
      app/controllers/admin/users_controller.rb
      app/controllers/api/v1/posts_controller.rb
    ].each do |path|
      assert Metz::FileClassifier.controller?(path), "expected controller? true for #{path}"
    end

    %w[
      lib/foo.rb
      app/models/user.rb
      app/views/users/index.html.erb
      app/controllers/users_controller.txt
      controllers/users_controller.rb
    ].each do |path|
      refute Metz::FileClassifier.controller?(path), "expected controller? false for #{path}"
    end
  end

  def test_view_predicate_matches_only_views_with_template_engine_extensions
    %w[
      app/views/users/index.html.erb
      app/views/users/show.html.haml
      app/views/users/edit.html.slim
      app/views/admin/users/_form.html.erb
    ].each do |path|
      assert Metz::FileClassifier.view?(path), "expected view? true for #{path}"
    end

    %w[
      app/views/users/index.html
      lib/template.erb
      app/controllers/users_controller.rb
      app/views/users/index.html.jbuilder
    ].each do |path|
      refute Metz::FileClassifier.view?(path), "expected view? false for #{path}"
    end
  end

  def test_model_predicate_matches_only_models
    %w[
      app/models/user.rb
      app/models/concerns/searchable.rb
    ].each do |path|
      assert Metz::FileClassifier.model?(path), "expected model? true for #{path}"
    end

    %w[
      app/controllers/users_controller.rb
      app/views/users/index.html.erb
      lib/user.rb
      app/models/user.txt
    ].each do |path|
      refute Metz::FileClassifier.model?(path), "expected model? false for #{path}"
    end
  end

  def test_relative_and_absolute_path_consistency_for_controllers
    rel = "app/controllers/x_controller.rb"
    abs = File.expand_path(rel)

    assert_equal Metz::FileClassifier.controller?(rel),
                 Metz::FileClassifier.controller?(abs)
    assert Metz::FileClassifier.controller?(abs),
           "expected absolute controller path to be classified as controller"
  end

  def test_relative_and_absolute_path_consistency_for_views
    rel = "app/views/x/index.html.erb"
    abs = File.expand_path(rel)

    assert_equal Metz::FileClassifier.view?(rel), Metz::FileClassifier.view?(abs)
    assert Metz::FileClassifier.view?(abs),
           "expected absolute view path to be classified as view"
  end

  def test_relative_and_absolute_path_consistency_for_models
    rel = "app/models/user.rb"
    abs = File.expand_path(rel)

    assert_equal Metz::FileClassifier.model?(rel), Metz::FileClassifier.model?(abs)
    assert Metz::FileClassifier.model?(abs),
           "expected absolute model path to be classified as model"
  end

  def test_predicates_are_disjoint_for_canonical_paths
    {
      "app/controllers/users_controller.rb" => :controller?,
      "app/views/users/index.html.erb" => :view?,
      "app/models/user.rb" => :model?
    }.each do |path, expected|
      others = %i[controller? view? model?] - [expected]
      assert Metz::FileClassifier.public_send(expected, path), "#{expected} must be true for #{path}"
      others.each do |predicate|
        refute Metz::FileClassifier.public_send(predicate, path),
               "#{predicate} must be false for #{path}"
      end
    end
  end
end
