# frozen_string_literal: true

require 'faker'
require_relative './model'

# Monkey patch string for fun and profit
class String
  def to_user
    { role: 'user', content: self }
  end
end

# Story DSL
class Story
  VERSION = '1.0.0'
  attr_accessor :characters, :scenes

  def initialize(&block)
    @characters = {}
    @scenes = []
    @messages = []
    @title = 'Untitled'
    instance_eval(&block)
  end

  def background(text)
    @background = text
  end

  def title(txt)
    @title = txt
  end

  def character(tag, &blk)
    @characters[tag] = Character.new(tag, &blk)
  end

  def scene(name, &blk)
    @scenes << Scene.new(name, self, &blk)
  end

  def context_messages
    ["Title #{@title}\n#{@background}".strip.to_user]
  end

  def character_context(people)
    characters_to_include = people.empty? ? @characters.keys : people.map { |name| characters[name] }
    characters_to_include.map { |name| characters[name].context }
  end

  def build_prompt(context, responses, prompt)
    prompt, setting, people = *prompt

    messages = context + character_context(people)
    messages << setting.to_user unless setting.empty?
    messages + responses.last(Model.max_responses).map(&:to_user) + ["PROMPT: #{prompt}".to_user]
  end

  def build
    puts "Build #{@title}"
    responses = []

    @scenes.each do |scene|
      puts "  #{scene.title}"
      context = context_messages
      scene.prompts.each do |prompt|
        puts "  #{prompt.inspect}"
        responses << Model.chat(build_prompt(context, responses, prompt))
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

  def initialize(name, &block)
    @name = name.to_s
    @traits = []
    instance_eval(&block)
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

def build_story(fname, body)
  body = "Story.new do\n#{body}\nend"

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

if __FILE__ == $PROGRAM_NAME

  ARGV.each do |fname|
    body = File.read(fname)

    if model?(body)
      build_model(fname, body)
    else
      build_story(fname, body)
    end
  end

end
