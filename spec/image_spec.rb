require 'spec_helper'

RSpec.describe ShareMeow::Image do
  let(:imgkit_double) { instance_double(IMGKit, to_img: 'fake-image', stylesheets: []) }

  let(:default_params) do
    { template: 'HelloWorld', 'message' => 'Hello, World' }
  end

  describe '.new' do
    it 'uses the correct template' do
      allow(ImageTemplates::HelloWorld).to receive(:new)

      described_class.new(default_params)

      expect(ImageTemplates::HelloWorld).to have_received(:new).with(default_params)
    end

    it 'raises an error if template is not implemented' do
      expect do
        described_class.new(template: 'Fake')
      end.to raise_error NotImplementedError, 'You must implement a Fake template'
    end
  end

  describe '#generate_and_store!' do
    let(:template_double) do
      instance_double(ImageTemplates::HelloWorld, to_html: 'fake',
                                                  filename: 'fake.jpg',
                                                  image_width: 300,
                                                  css_stylesheet: 'fake.css',
                                                  image_quality: 100,
                                                  cache_key: 'not-real')
    end

    let(:store_image_double) do
      instance_double(ShareMeow::StoreImage,
                      store!: 'https://sharemeow.s3.stubbed-region.amazonaws.com/fake.jpg')
    end

    before do
      allow(IMGKit).to receive(:new).and_return imgkit_double
      allow(ShareMeow::StoreImage).to receive(:new).and_return store_image_double
      allow(ImageTemplates::HelloWorld).to receive(:new).and_return template_double
    end

    before(:each) do
      Redis.new.flushall
    end

    it 'returns the public image url' do
      image_url = described_class.new(default_params).generate_and_store!

      expect(image_url).to eq 'https://sharemeow.s3.stubbed-region.amazonaws.com/fake.jpg'
    end

    it 'initializes IMGkit with the correct params' do
      described_class.new(default_params).generate_and_store!

      expect(IMGKit).to have_received(:new).with('fake', zoom: 2, width: 300, quality: 100)
    end

    it 'generates a jpg with IMGKit' do
      described_class.new(default_params).generate_and_store!

      expect(imgkit_double).to have_received(:to_img).with(:jpg)
    end

    it 'stores the image on remote storage (s3)' do
      described_class.new(default_params).generate_and_store!

      expect(ShareMeow::StoreImage).to have_received(:new).with('fake.jpg', 'fake-image')
    end

    describe 'caching' do
      before do
        allow(ImageTemplates::HelloWorld).to receive(:new).and_call_original
      end

      it 'caches the image generation' do
        described_class.new(default_params).generate_and_store!
        described_class.new(default_params).generate_and_store!

        expect(ShareMeow::StoreImage).to have_received(:new).once
      end

      it 'does not use cache if params change' do
        described_class.new(default_params).generate_and_store!

        described_class.new(default_params.merge('message' => 'this is different')).generate_and_store!

        expect(ShareMeow::StoreImage).to have_received(:new).twice
      end
    end
  end
end
