require "spec_helper"

describe Lita::Logger do
  let(:io) { StringIO.new }

  it "uses a custom log level" do
    logger = described_class.get_logger(:debug, nil)
    expect(logger.level).to eq(Logger::DEBUG)
  end

  it "uses the info level if the config is nil" do
    logger = described_class.get_logger(nil, nil)
    expect(logger.level).to eq(Logger::INFO)
  end

  it "uses the info level if the config level is invalid" do
    logger = described_class.get_logger(:foo, nil)
    expect(logger.level).to eq(Logger::INFO)
  end

  it "uses any custom formatter provided" do
    logger = described_class.get_logger(:debug, proc { "custom" }, io: io)
    logger.fatal "foo"
    expect(io.string).to eq("custom")
  end
end
