require "spec_helper"

describe Lita do
  describe ".load_locales" do
    let(:load_path) do
      load_path = double("Array")
      allow(load_path).to receive(:concat)
      load_path
    end

    let(:new_locales) { %w(foo bar) }

    before do
      allow(I18n).to receive(:load_path).and_return(load_path)
      allow(I18n).to receive(:reload!)
    end

    it "appends the locale files to I18n.load_path" do
      expect(I18n.load_path).to receive(:concat).with(new_locales)
      described_class.load_locales(new_locales)
    end

    it "reloads I18n" do
      expect(I18n).to receive(:reload!)
      described_class.load_locales(new_locales)
    end

    it "wraps single paths in an array" do
      expect(I18n.load_path).to receive(:concat).with(["foo"])
      described_class.load_locales("foo")
    end
  end

  describe ".locale=" do
    it "sets I18n.locale to the normalized locale" do
      expect(I18n).to receive(:locale=).with("es-MX.UTF-8")
      described_class.locale = "es_MX.UTF-8"
    end
  end

  describe ".run" do
    let(:hook) { double("Hook") }
    let(:validator) { instance_double("Lita::ConfigurationValidator", call: nil) }

    before do
      allow_any_instance_of(Lita::Robot).to receive(:run)
      allow(
        Lita::ConfigurationValidator
      ).to receive(:new).with(described_class).and_return(validator)
    end

    after { described_class.reset }

    it "runs a new Robot" do
      expect_any_instance_of(Lita::Robot).to receive(:run)
      described_class.run
    end

    it "calls before_run hooks" do
      described_class.register_hook(:before_run, hook)
      expect(hook).to receive(:call).with(config_path: "path/to/config")
      described_class.run("path/to/config")
    end

    it "calls config_finalized hooks" do
      described_class.register_hook(:config_finalized, hook)
      expect(hook).to receive(:call).with(config_path: "path/to/config")
      described_class.run("path/to/config")
    end

    it "raises if the configuration is not valid" do
      allow(validator).to receive(:call).and_raise(SystemExit)

      expect { described_class.run }.to raise_error(SystemExit)
    end
  end
end
