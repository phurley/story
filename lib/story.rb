# frozen_string_literal: true

require 'faker'
require_relative './model'

# Monkey patch string for fun and profit
class String
  def to_assistant
    { role: 'assistant', content: self }
  end

  def to_user
    { role: 'user', content: self }
  end

  def proper
    self.split(/\s+/).map(&:capitalize).join(' ')
  end
end

# Story DSL
class Story
  VERSION = '1.0.0'
  attr_accessor :characters, :scenes

  def initialize(fname: 'story', &block)
    @characters = {}
    @scenes = []
    @messages = []
    @title = 'Untitled'
    @fname = fname
    instance_eval(&block)
  end

  def background(text)
    @background = text
  end

  def title(txt)
    @title = txt
  end

  def plot(txt)
    @plot = txt
  end

  def character(tag, simple = nil, traits: [], name: tag.to_s.proper, &blk)
    traits << simple if simple
    @characters[tag] = Character.new(name: name, traits: traits, &blk)
  end

  def scene(name, &blk)
    @scenes << Scene.new(name, self, &blk)
  end

  def context_messages
    ["Title #{@title}\n#{@background}".strip.to_user]
  end

  def character_context(people)
    characters_to_include = people.empty? ? @characters.keys : people
    characters_to_include.map { |name| characters[name].context }
  rescue NoMethodError
    puts "Unable to find someone #{people.inspect}"
    exit 1
  end

  def build_prompt(context, responses, prompt)
    prompt, setting, people = *prompt

    messages = context + character_context(people)
    if setting && !setting.empty?
      messages << setting.to_user
    end
    messages + responses.last(Model.max_responses).map(&:to_assistant) + ["PROMPT: #{prompt}".to_user]
  end

  def build
    puts "Build #{@title}"
    responses = []

    @scenes.each do |scene|
      puts "  #{scene.title}"
      context = context_messages
      scene.prompts.each do |prompt|
        Model.logger.info "\n\n> #{prompt}\n\n"
        responses << Model.chat(build_prompt(context, responses, prompt))
        File.write(@fname, responses.last + "\n", mode: "a")
      end
    end
  end
end

def story(&block)
  Story.new(&block)
end

# Character
class Character
  attr_reader :traits

  def initialize(traits: [], name: Faker::Name.unique.first_name, &block)
    @name = name
    @traits = traits
    instance_eval(&block) if block_given?
  end

  def name(txt)
    @name = txt
  end

  def trait(msg)
    @traits << msg
  end

  def context
    "#{@name}: #{traits.join("\n")}".to_user
  end
end

# Scene
class Scene
  attr_accessor :names
  attr_reader :title, :prompts

  def initialize(title, story, &blk)
    @story = story
    @title = title
    @names = []
    @prompts = []
    instance_eval(&blk)
  end

  def duration(text)
    @duration = text
  end

  def characters(*names)
    @names = names
  end

  def setting(text)
    @setting = text
  end

  def prompt(text)
    @prompts << [text, @setting, @names]
  end
end

def model?(body)
  body.match(/^\s*model\s+\S+/) &&
    !body.match(/^\s*title/) &&
    !body.match(/^\s*scene/)
end

def runpod?(body)
  body.match(/^\s*runpod\s+\S+/) &&
    !body.match(/^\s*title/) &&
    !body.match(/^\s*scene/)
end

def build_story(fname, body)
  base_dir  = File.dirname(fname)
  base_name = File.basename(fname, File.extname(fname))
  ext       = '.log'

  counter = 1
  log_name = File.join(base_dir, format("%s-%03d%s", base_name, counter, ext))

  # Ensure unique filename by appending -001, -002, etc.
  while File.exist?(log_name)
    log_name = File.join(base_dir, format("%s-%03d%s", base_name, counter, ext))
    counter += 1
  end
  puts "Log to #{log_name}"

  body = "Story.new(fname: #{log_name.inspect}) do\n#{body}\nend"

  # rubocop:disable Security/Eval
  eval(body, nil, fname, 0).build
  # rubocop:enable Security/Eval
end

def build_model(fname, body)
  body = "Model.new do\n#{body}\nend"

  # rubocop:disable Security/Eval
  eval(body, nil, fname, 0)
  # rubocop:enable Security/Eval
end

def build
  ARGV.each do |fname|
    body = File.read(fname)

    if model?(body) || runpod?(body)
      build_model(fname, body)
    else
      build_story(fname, body)
    end
  end
end

if __FILE__ == $PROGRAM_NAME

  build

end
