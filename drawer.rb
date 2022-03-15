class Drawer
  attr_reader :stages, :jobs
  def initialize(pipeline)
    @pipeline = pipeline
    @current_y = 0

    @stages = draw_stages
    @jobs = draw_jobs
  end

  private

  def draw_stages
    @pipeline
      .stages
      .map { |stage| to_drawing_stage(stage) }
  end

  def to_drawing_stage(stage)
    {
      data: stage.data,
    }
  end

  def draw_jobs
    @pipeline
      .stages
      .select { |stage| stage.has_jobs? }
      .flat_map { |stage| stage.jobs.map { |job| to_drawing_job(stage, job) } }
  end

  def to_drawing_job(stage, job)
    {
      data: job.data,
    }
  end
end
