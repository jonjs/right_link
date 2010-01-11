require File.join(File.dirname(__FILE__), '..', '..', 'spec', 'spec_helper')
require 'instance_commands'
require 'command_io'
require 'agent_identity'

describe RightScale::InstanceCommands do

  before(:all) do
    @commands = RightScale::InstanceCommands::COMMANDS
    @agent_identity = RightScale::AgentIdentity.new('rs', 'test', 1).to_s
    @scheduler = flexmock('Scheduler')
    @scheduler.should_ignore_missing
  end

  it 'should list commands' do
    flexmock(RightScale::CommandIO.instance).should_receive(:reply).and_return do |conn, r|
      conn.should == 42
      r.count("\n").should == @commands.size + 6
    end
    RightScale::InstanceCommands.new(@agent_identity, @scheduler).send(:list_command, {:conn => 42}).should be_true
  end

  it 'should get commands' do
    cmds = RightScale::InstanceCommands.get(@agent_identity, @scheduler)
    cmds.size.should == @commands.size
    cmds.keys.map { |k| k.to_s }.sort.should == @commands.keys.map { |k| k.to_s }.sort
    cmds.values.all? { |v| v.is_a? Proc }.should be_true
  end

end