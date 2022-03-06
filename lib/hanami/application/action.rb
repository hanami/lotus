# frozen_string_literal: true

require "hanami/action"
require "hanami/slice_configurable"

module Hanami
  class Application
    class Action < Hanami::Action
      class Configuration < Hanami::Action::Configuration
        setting :view_name_inferrer
        setting :view_context_identifier
      end

      extend Hanami::SliceConfigurable

      class << self
        # @api private
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@slice, slice)
        end

        # @api public
        def configuration
          @configuration ||= Application::Action::Configuration.new
        end

        # FIXME: figure out why I actually need this given we have alias_method in the base class
        def config
          configuration
        end

        # @api private
        def configure_for_slice(slice)
          @slice = slice

          actions_config = slice.application.config.actions

          configure_from_actions_config(actions_config)
          extend_behavior(actions_config)
        end

        # @api private
        def slice
          @slice
        end

        # @api private
        def application
          slice.application
        end

        private

        def configure_from_actions_config(actions_config)
          config.settings.each do |setting|
            config.public_send :"#{setting}=", actions_config.public_send(:"#{setting}")
          end
        end

        def extend_behavior(actions_config)
          if actions_config.sessions.enabled?
            require "hanami/action/session"
            include Hanami::Action::Session
          end

          if actions_config.csrf_protection
            require "hanami/action/csrf_protection"
            include Hanami::Action::CSRFProtection
          end

          if actions_config.cookies.enabled?
            require "hanami/action/cookies"
            include Hanami::Action::Cookies
          end
        end
      end

      attr_reader :view, :view_context, :routes

      def initialize(
        view: resolve_paired_view,
        view_context: resolve_view_context,
        routes: resolve_routes,
        **dependencies
      )
        @view = view
        @view_context = view_context
        @routes = routes

        super(**dependencies)
      end

      def inspect
        "#<#{self.class.name}[#{self.class.slice.name}]>"
      end

      def build_response(**options)
        options = options.merge(view_options: method(:view_options))
        super(**options)
      end

      def view_options(req, res)
        {context: view_context&.with(**view_context_options(req, res))}.compact
      end

      def view_context_options(req, res)
        {request: req, response: res}
      end

      def finish(req, res, halted)
        res.render(view, **req.params) if render?(res)
        super
      end

      # Decide whether to render the current response with the associated view.
      # This can be overridden to enable/disable automatic rendering.
      #
      # @param res [Hanami::Action::Response]
      #
      # @return [TrueClass,FalseClass]
      #
      # @since 2.0.0
      # @api public
      def render?(res)
        view && res.body.empty?
      end

      private

      def resolve_paired_view
        # There's a lot of class-level things going on... and no instance-level state
        # required... I wonder if this can move to the class level

        # Is `config` injected to the instance with actions? It might be, meaning I don't
        # have to reach to the class for it
        view_identifiers = self.class.config.view_name_inferrer.call(
          action_name: self.class.name,
          provider: self.class.slice,
        )

        view_identifiers.detect do |identifier|
          break self.class.slice[identifier] if self.class.slice.key?(identifier)
        end
      end

      def resolve_view_context
        identifier = self.class.config.view_context_identifier

        if self.class.slice.key?(identifier)
          self.class.slice[identifier]
        elsif self.class.application.key?(identifier)
          # TODO: we might not need the fallback with the way we're setting up the view layer for slices now
          self.class.application[identifier]
        end
      end

      def resolve_routes
        # TODO: turn this into a config
        self.class.application[:routes_helper] if self.class.application.key?(:routes_helper)
      end
    end
  end
end
