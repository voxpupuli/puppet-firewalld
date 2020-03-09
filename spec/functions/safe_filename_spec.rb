require 'spec_helper'

describe 'firewalld::safe_filename' do
  let(:valid_filenames) do
    {
      'ThisShouldWork' => 'ThisShouldWork',
      'this_should_work' => 'this_should_work',
      'th1s_Sh0uld_w0rk' => 'th1s_Sh0uld_w0rk'
    }
  end

  let(:invalid_filenames) do
    {
      'This Should Work' => 'This_Should_Work',
      'this should work'   => 'this_should_work',
      'th1s$Sh0uld w0rk!!' => 'th1s_Sh0uld_w0rk__'
    }
  end

  let(:filenames_with_options) do
    {
      'ThisShouldWork.test' => 'ThisShouldWork.test',
      'this_should_!work.xml'   => 'this_should_--work--xml',
      'th1s$Sh0uld w0rk!!.test' => 'th1s--Sh0uld--w0rk----.test'
    }
  end

  it 'runs with valid filenames' do
    valid_filenames.each do |k, v|
      is_expected.to run.with_params(k).and_return(v)
    end
  end

  it 'translates invalid filenames' do
    invalid_filenames.each do |k, v|
      is_expected.to run.with_params(k).and_return(v)
    end
  end

  it 'translates with options' do
    filenames_with_options.each do |k, v|
      opts = {
        'replacement_string' => '--',
        'file_extension'     => '.test'
      }

      is_expected.to run.with_params(k, opts).and_return(v)
    end
  end

  it 'raises an error if provided with an invalid replacement_string' do
    expect do
      is_expected.to run.with_params('test', 'replacement_string' => '@')
    end.to raise_error(%r{expects a match for.+got '@'})
  end
end
