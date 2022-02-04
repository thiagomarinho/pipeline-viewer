# TODO map methods to yaml attributes using method_missing
class String
  def parameterize
    return self.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  end
end

class Pipeline
  def initialize(yaml)
    @yaml = yaml
    @stages = @yaml['stages'].map { |stage| Stage.new(stage, self) }
  end

  attr_reader :stages

  def jobs
    stages.flat_map { |stage| stage.jobs }.reject { |job| job.to_s.empty? }
  end

  def stage(name)
    stage = @stages.find { |stage| stage.name == name }

    raise "Stage not found: #{name}" unless stage

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

class Stage
  def self.id(instance)
    return "stage_#{instance.name}".parameterize
  end

  attr_reader :jobs, :name, :parent

  def initialize(yaml, parent)
    @yaml = yaml
    @name = @yaml['stage']
    @parent = parent

    if @yaml['jobs']
      @jobs = @yaml['jobs'].map { |job| JobFactory.create_job(job, self) }
    end
  end

  def id
    Stage.id(self)
  end

  def previous_stage
    return nil if first_stage?

    @parent.stages[my_index - 1]
  end

  def next_stage
    return nil if last_stage?

    @parent.stages[my_index + 1]
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

  def job(name)
    job = @jobs.find { |job| job.name == name }

    raise "Job not found: #{name}" unless job

    job
  end

  def data
    {
      id: id,
      name: name
    }
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

class Job
  def self.id(instance)
    return "job_#{instance.parent.id}_#{instance.name}".parameterize
  end

  def initialize(yaml, parent)
    @yaml = yaml
    @name = @yaml['job']
    @parent = parent
  end

  def id
    Job.id(self)
  end

  def data
    {
      id: id,
      name: name,
      parent: parent.id
    }
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

  attr_reader :name, :parent
end

class DeploymentJob < Job
  def initialize(yaml, parent)
    @yaml = yaml
    @name = @yaml['deployment']
    @parent = parent
  end
end

def to_model(raw)
  yaml = YAML.load(raw)

  return Pipeline.new(yaml)
end
