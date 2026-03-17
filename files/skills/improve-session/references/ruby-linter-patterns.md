# Ruby Linter Patterns

Pre-built CLAUDE.md snippets for the most common Ruby linting issues Claude triggers.
Use these as templates when generating recommendations.

## Reek Smells

### FeatureEnvy

```markdown
## Reek: FeatureEnvy

When a method accesses multiple attributes of another object, it has "Feature Envy" — it wants to be on that object instead. Extract the accessed attributes into local variables or move the logic.

BAD:
```ruby
def format_address
  "#{user.street}, #{user.city}, #{user.state} #{user.zip}"
end
```

GOOD:
```ruby
def format_address
  street, city, state, zip = user.values_at(:street, :city, :state, :zip)
  "#{street}, #{city}, #{state} #{zip}"
end
```

Alternative: Use destructuring or move the method onto the data object.
```

### TooManyStatements

```markdown
## Reek: TooManyStatements

Keep methods under 10 statements (project threshold). Extract logical groups into private helper methods.

BAD:
```ruby
def process
  validate_input
  data = fetch_data
  transformed = transform(data)
  filtered = filter(transformed)
  sorted = sort(filtered)
  formatted = format(sorted)
  cache_result(formatted)
  log_completion
  notify_subscribers
  formatted
end
```

GOOD:
```ruby
def process
  validate_input
  result = fetch_and_transform
  finalize(result)
end

private

def fetch_and_transform
  data = fetch_data
  transform(data).then { filter(_1) }.then { sort(_1) }
end

def finalize(result)
  formatted = format(result)
  cache_result(formatted)
  log_completion
  notify_subscribers
  formatted
end
```
```

### DuplicateMethodCall

```markdown
## Reek: DuplicateMethodCall

When the same method is called multiple times with the same receiver, extract it into a local variable.

BAD:
```ruby
if config.enabled?
  process(config.timeout, config.retries)
  log("Config: #{config.timeout}s, #{config.retries} retries")
end
```

GOOD:
```ruby
if config.enabled?
  timeout = config.timeout
  retries = config.retries
  process(timeout, retries)
  log("Config: #{timeout}s, #{retries} retries")
end
```
```

### ControlParameter

```markdown
## Reek: ControlParameter

Don't use method parameters as boolean flags to control flow. Use separate methods, predicates, or hash dispatch.

BAD:
```ruby
def render(format)
  if format == :json
    render_json
  elsif format == :xml
    render_xml
  else
    render_html
  end
end
```

GOOD:
```ruby
RENDERERS = {
  json: ->(data) { render_json(data) },
  xml: ->(data) { render_xml(data) },
  html: ->(data) { render_html(data) }
}.freeze

def render(format)
  RENDERERS.fetch(format, RENDERERS[:html]).call(data)
end
```
```

### DataClump

```markdown
## Reek: DataClump

When the same group of parameters travels together across methods, bundle them into a Struct or Data.define.

BAD:
```ruby
def connect(host, port, timeout)
  socket = open(host, port)
  configure(host, port, timeout)
end
```

GOOD:
```ruby
ConnectionConfig = Data.define(:host, :port, :timeout)

def connect(config)
  socket = open(config.host, config.port)
  configure(config)
end
```
```

### UncommunicativeVariableName

```markdown
## Reek: UncommunicativeVariableName

Use descriptive variable names. Avoid single-letter names except for well-known conventions (i, j for indices, e for exceptions, _ for unused).

BAD: `d = fetch_data` / `r = process(d)` / `x = transform(r)`
GOOD: `data = fetch_data` / `result = process(data)` / `output = transform(result)`
```

### InstanceVariableAssumption

```markdown
## Reek: InstanceVariableAssumption

Don't assume instance variables are set. Initialize them in the constructor or use lazy initialization.

BAD:
```ruby
def process
  @cache ||= {}
  @cache[key] = value
end
```

GOOD:
```ruby
def initialize
  @cache = {}
end

def process
  @cache[key] = value
end
```
```

## RuboCop Cops

### Metrics/MethodLength

```markdown
## RuboCop: Metrics/MethodLength

Keep methods short. Default max is 10 lines. Extract helper methods for logical groups of statements.

When you write a method, count the lines. If approaching the limit, proactively extract before the linter complains.
```

### Layout/MultilineMethodCallBraceLayout

```markdown
## RuboCop: Layout/MultilineMethodCallBraceLayout

When a method call spans multiple lines and the opening brace is on a separate line from the first argument, the closing brace must be on its own line after the last argument.

BAD:
```ruby
result = method_call(
  arg1,
  arg2)
```

GOOD:
```ruby
result = method_call(
  arg1,
  arg2
)
```
```

### Style/GuardClause

```markdown
## RuboCop: Style/GuardClause

Use guard clauses for early returns instead of wrapping the body in a conditional.

BAD:
```ruby
def process
  if valid?
    # many lines of code
  end
end
```

GOOD:
```ruby
def process
  return unless valid?

  # many lines of code
end
```
```

### Naming/MethodParameterName

```markdown
## RuboCop: Naming/MethodParameterName

Method parameter names should be at least 3 characters. Use descriptive names.

BAD: `def process(x, y)` / `def connect(to)`
GOOD: `def process(input, output)` / `def connect(target)`
```

### Metrics/AbcSize

```markdown
## RuboCop: Metrics/AbcSize

ABC size measures Assignments, Branches, and Conditions. Reduce by:
- Extracting conditionals into predicate methods
- Extracting assignments into helper methods
- Reducing branching with guard clauses or early returns
```

### Metrics/CyclomaticComplexity

```markdown
## RuboCop: Metrics/CyclomaticComplexity

Reduce branching in methods. Each `if`, `unless`, `when`, `&&`, `||` adds complexity. Extract branches into separate methods or use polymorphism/hash dispatch.
```
