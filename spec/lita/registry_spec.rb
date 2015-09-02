require "spec_helper"

describe Lita::Registry do
  let(:log_output) { StringIO.new }

  before do
    subject.logger = Lita::Logger.get_logger(:debug, nil, io: log_output)
  end

  describe "#configure" do
    it "applies supplied blocks to the configuration object when it's created" do
      subject.configure { |c| c.robot.name = "Not Lita" }

      subject.initialize_config

      expect(subject.config.robot.name).to eq("Not Lita")
    end
  end

  describe "#redis" do
    let(:redis_namespace) { double("Redis::Namespace") }

    before do
      allow(redis_namespace).to receive(:del)
      allow(redis_namespace).to receive(:keys).and_return([])
      allow(redis_namespace).to receive(:ping).and_return("PONG")
      allow(Redis::Namespace).to receive(:new).and_return(redis_namespace)
    end

    it "stores a Redis::Namespace" do
      subject.finalize

      expect(subject.redis).to equal(redis_namespace)
    end

    it "raises a RedisError if it can't connect to Redis" do
      allow(redis_namespace).to receive(:ping).and_raise(Redis::CannotConnectError)

      expect { subject.finalize }.to raise_error(Lita::RedisError, /could not connect to Redis/)
    end

    context "with test mode off" do
      around do |example|
        test_mode = Lita.test_mode?
        Lita.test_mode = false
        example.run
        Lita.test_mode = test_mode
      end

      it "logs a fatal warning and raises an exception if it can't connect to Redis" do
        allow(redis_namespace).to receive(:ping).and_raise(Redis::CannotConnectError)

        expect { subject.finalize }.to raise_error(SystemExit)

        expect(log_output.string).to include("could not connect to Redis")
      end
    end
  end

  describe "#register_adapter" do
    let(:robot) { Lita::Robot.new(subject) }

    it "builds an adapter out of a provided block" do
      subject.register_adapter(:foo) {}

      subject.adapters[:foo].new(robot).run

      expect(log_output.string).to include("not implemented")
    end

    it "raises if a non-class object is passed as the adapter" do
      expect do
        subject.register_adapter(:foo, :bar)
      end.to raise_error(ArgumentError, /requires a class/)
    end
  end

  describe "#register_handler" do
    it "builds a handler out of a provided block" do
      subject.register_handler(:foo) {}

      expect(subject.handlers.to_a.last.namespace).to eq("foo")
    end

    it "raises if a non-class object is the only argument" do
      expect do
        subject.register_handler(:foo)
      end.to raise_error(ArgumentError, /requires a class/)
    end
  end

  describe "#register_hooks" do
    let(:hook) { double("hook") }

    it "stores and de-dupes registered hooks" do
      subject.register_hook("Foo ", hook)
      subject.register_hook(:foO, hook)

      expect(subject.hooks[:foo]).to eq(Set.new([hook]))
    end
  end

  describe "#reset" do
    it "clears the config" do
      subject.initialize_config
      subject.config.robot.name = "Foo"

      subject.reset

      subject.initialize_config
      expect(subject.config.robot.name).to eq("Lita")
    end

    it "clears adapters" do
      subject.register_adapter(:foo, Class.new)

      subject.reset

      expect(subject.adapters).to be_empty
    end

    it "clears handlers" do
      subject.register_handler(Class.new)

      subject.reset

      expect(subject.handlers).to be_empty
    end

    it "clears hooks" do
      subject.register_hook(:foo, double)

      subject.reset

      expect(subject.hooks).to be_empty
    end
  end
end
