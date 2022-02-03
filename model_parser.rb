# TODO map methods to yaml attributes using method_missing
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
    @stages.find { |stage| stage.name == name }
  end
end

class Stage
  def self.id(instance)
    return "stage_#{instance.name}"
  end

  attr_reader :jobs, :name, :parent

  def initialize(yaml, parent)
    @yaml = yaml
    @name = @yaml['stage']
    @parent = parent
    @jobs = @yaml['jobs'].map { |job| Job.new(job, self) } if @yaml['jobs']
  end

  def id
    Stage.id(self)
  end

  def job(name)
    @jobs.find { |job| job.name == name }
  end

  def data
    {
      id: id,
      name: name
    }
  end

  def edge_data
    {
      id: "stage_#{id}_depends_on_#{depends_on.id}",
      source: depends_on.id,
      target: id
    }
  end

  def has_jobs?
    @jobs && !@jobs.empty?
  end

  def has_dependency?
    @yaml['dependsOn']
  end

  def depends_on
    if has_dependency?
      return @parent.stage(@yaml['dependsOn'])
    end

    nil
  end
end

class Job
  def self.id(instance)
    return "job_#{instance.parent.name}_#{instance.name}"
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
    @yaml['dependsOn']
  end

  def depends_on
    if has_dependency?
      return @parent.job(@yaml['dependsOn'])
    end

    nil
  end

  def edge_data
    {
      id: "job_#{id}_depends_on_#{depends_on.id}",
      source: depends_on.id,
      target: id
    }
  end

  attr_reader :name, :parent
end

def to_model(raw)
  yaml = YAML.load(raw)

  return Pipeline.new(yaml)
end
