return {
  'AlexandrosAlexiou/kotlin.nvim',
  ft = { 'kotlin' },
  dependencies = {
    'mason.nvim',
    'stevearc/oil.nvim',
    'folke/trouble.nvim',
  },
  config = function()
    require('kotlin').setup({
      root_markers = {
        'gradlew',
        '.git',
        'mvnw',
        'settings.gradle',
        'settings.gradle.kts',
        'build.gradle',
        'build.gradle.kts',
        'pom.xml',
      },
      jre_path = nil,
      jdk_for_symbol_resolution = os.getenv('JAVA_HOME'),
      jvm_args = {
        '-Xmx4g',
      },
      inlay_hints = {
        enabled = true,
        parameters = true,
        parameters_compiled = true,
        parameters_excluded = false,
        types_property = true,
        types_variable = true,
        function_return = true,
        function_parameter = true,
        lambda_return = true,
        lambda_receivers_parameters = true,
        value_ranges = true,
        kotlin_time = true,
      },
    })
  end,
}
