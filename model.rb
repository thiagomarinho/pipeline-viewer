# TODO map methods to yaml attributes using method_missing
class String
  def parameterize
    return self.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  end
end

class Pipeline
  attr_reader :stages, :jobs

  def initialize(yaml)
    @yaml = yaml
    @stages = @yaml['stages'].map { |stage| Stage.new(stage, self) }
    @jobs = @stages.flat_map { |stage| stage.jobs }.reject { |job| job.to_s.empty? }
  end

  def stage(internal_id)
    stage = @stages.find { |stage| stage.internal_id == internal_id }

    raise "Stage not found: #{internal_id}" unless stage

    stage
  end
end

class JobFactory
  def self.create_job(yaml, parent)
    return DeploymentJob.new(yaml, parent) if yaml['deployment']
    return Job.new(yaml, parent) if yaml['job']

    raise "Unexpected job type defined by: #{yaml.inspect}"
  end
end

class Base
  attr_reader :internal_id, :id, :display_name, :parent, :children

  def initialize(yaml, parent)
    @yaml = yaml
    @display_name = @yaml['displayName']
    @parent = parent
  end

  def name
    @display_name || @internal_id
  end
end

class Stage < Base
  attr_reader :jobs

  def initialize(yaml, parent)
    super(yaml, parent)

    @internal_id = yaml['stage']
    @id = "stage_#{@internal_id}".parameterize
    @pool = yaml['pool']

    if yaml['jobs']
      @jobs = yaml['jobs'].map { |job| JobFactory.create_job(job, self) }
    end
  end

  def previous_stage
    return nil if first_stage?

    @parent.stages[my_index - 1]
  end

  def next_stage
    return nil if last_stage?

    @parent.stages[my_index + 1]
  end

  def siblings
    stages_from_parent = @parent.stages.dup

    stages_from_parent.delete_at(my_index)

    stages_from_parent
  end

  def siblings_and_me
    @parent.stages
  end

  def dependency_level
    return 0 if depends_on.empty?
    return 1 + depends_on.map { |dependency| dependency.dependency_level }.max
  end

  def my_index_at_my_level
    my_dependency_level = dependency_level
    my_id = id

    siblings_and_me.select { |sibling| sibling.dependency_level == my_dependency_level }.index { |item| item.id == my_id }
  end

  def my_index
    @my_index ||= @parent.stages.find_index { |stage| stage.name == name }
  end

  def last_stage?
    my_index == @parent.stages.size - 1
  end

  def first_stage?
    my_index == 0
  end

  def job(internal_id)
    job = @jobs.find { |job| job.internal_id == internal_id }

    raise "Job not found: #{internal_id}" unless job

    job
  end

  def data
    {
      type: 'Stage',
      id: id,
      internal_id: internal_id,
      name: name,
      children_type: 'Jobs',
      children: jobs.map { |job| job.name },
      attributes: attributes
    }
  end

  def attributes
    attributes = []
    attributes << { name: :pool, value: @pool } if @pool

    attributes.compact
  end

  def depends_on
    if has_explicit_dependency?
      return [@parent.stage(@yaml['dependsOn'])] if @yaml['dependsOn'].is_a? String
      return @yaml['dependsOn'].map { |dependency| @parent.stage(dependency) } if @yaml['dependsOn'].is_a? Array

      raise "Unexpected type for dependsOn: #{@yaml['dependsOn'].class.name}"
    end

    unless has_no_dependency?
      return [previous_stage] if previous_stage
    end

    []
  end

  def edge_data
    depends_on.map { |dependency| {
      data: {
        id: "stage_#{id}_depends_on_#{dependency.id}",
        source: dependency.id,
        target: id
      }
    } }
  end

  def has_jobs?
    @jobs && !@jobs.empty?
  end

  # When you define multiple stages in a pipeline, by default, they run sequentially in the order in which you define them in the YAML file:
  # https://docs.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml#specify-dependencies
  # if dependsOn is [], then the stage has no dependency and it will run in parallel with the first one
  # if dependsOn is not specified then the stage will run sequentially
  # if two stages depends on the same stage, they will run in parallel
  def has_explicit_dependency?
    @yaml['dependsOn'] && !@yaml['dependsOn'].empty?
  end

  def has_no_dependency?
    @yaml['dependsOn'] && @yaml['dependsOn'].is_a?(Array) && @yaml['dependsOn'].empty?
  end

  def has_dependency?
    !has_no_dependency?
  end
end

class Job < Base
  def initialize(yaml, parent, id_key='job')
    super(yaml, parent)

    @internal_id = yaml[id_key]
    @id = "job_#{parent.id}_#{@internal_id}".parameterize
    @pool = yaml['pool']
    @container = yaml['container']
  end

  def data
    {
      type: 'Job',
      id: id,
      internal_id: internal_id,
      name: name,
      parent: parent.id,
      children_type: 'Steps',
      children: [],
      attributes: attributes
    }
  end

  def attributes
    attributes = []
    attributes << { name: :pool, value: @pool } if @pool
    attributes << { name: :container, value: @container } if @container

    attributes.compact
  end

  def has_dependency?
    @yaml['dependsOn'] && !@yaml['dependsOn'].empty?
  end

  def depends_on
    if has_dependency?
      return [@parent.job(@yaml['dependsOn'])] if @yaml['dependsOn'].is_a? String
      return @yaml['dependsOn'].map { |dependency| @parent.job(dependency) } if @yaml['dependsOn'].is_a? Array

      raise "Unexpected type for dependsOn: #{@yaml['dependsOn'].class.name}"
    end

    []
  end

  def edge_data
    depends_on.map { |dependency| {
      data: {
        id: "job_#{id}_depends_on_#{dependency.id}",
        source: dependency.id,
        target: id
      }
    } }
  end
end

class DeploymentJob < Job
  def initialize(yaml, parent)
    super(yaml, parent, 'deployment')
  end
end

def to_model(raw)
  yaml = YAML.load(raw)

  return Pipeline.new(yaml)
end
