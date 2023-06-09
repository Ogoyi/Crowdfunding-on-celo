// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC20Token {
    function transfer(address, uint256) external returns (bool);

    function approve(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract CrowdfundingPlatform {
    using SafeMath for uint256;

    uint internal projectCount = 0;
    address internal celoTokenAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

    struct Project {
        address payable creator;
        uint256 targetAmount;
        uint256 totalAmountRaised;
        uint256 deadline;
        bool isActive;
        bool isFunded;
    }

    mapping(uint => Project) internal projects;

    event ProjectCreated(
        uint indexed projectId,
        address indexed creator,
        uint256 targetAmount,
        uint256 deadline
    );

    event ProjectFunded(uint indexed projectId, address indexed backer, uint256 amount);

    event ProjectCompleted(uint indexed projectId, address indexed creator, uint256 totalAmountRaised);

    function createProject(
        uint256 _targetAmount,
        uint256 _deadline
    ) external {
        require(_targetAmount > 0, "Target amount must be greater than zero");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        Project storage newProject = projects[projectCount];
        newProject.creator = payable(msg.sender);
        newProject.targetAmount = _targetAmount;
        newProject.totalAmountRaised = 0;
        newProject.deadline = _deadline;
        newProject.isActive = true;
        newProject.isFunded = false;

        emit ProjectCreated(
            projectCount,
            newProject.creator,
            newProject.targetAmount,
            newProject.deadline
        );

        projectCount++;
    }

    function fundProject(uint _projectId) external payable {
        require(_projectId < projectCount, "Invalid project ID");

        Project storage project = projects[_projectId];
        require(project.isActive, "Project is not active");
        require(!project.isFunded, "Project has already been funded");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.value > 0, "Funding amount must be greater than zero");

        uint256 remainingAmount = project.targetAmount.sub(project.totalAmountRaised);
        uint256 actualAmount = msg.value;
        if (actualAmount > remainingAmount) {
            actualAmount = remainingAmount;
        }

        project.totalAmountRaised = project.totalAmountRaised.add(actualAmount);

        if (project.totalAmountRaised >= project.targetAmount) {
            project.isFunded = true;
            project.isActive = false;
            emit ProjectCompleted(_projectId, project.creator, project.totalAmountRaised);
        }

        emit ProjectFunded(_projectId, msg.sender, actualAmount);
    }

    function withdrawFunds(uint _projectId) external {
        require(_projectId < projectCount, "Invalid project ID");

        Project storage project = projects[_projectId];
        require(!project.isActive, "Project is still active");
        require(project.isFunded, "Project has not been successfully funded");
        require(project.creator == msg.sender, "Only the project creator can withdraw funds");

        uint256 amount = project.totalAmountRaised;

        require(payable(project.creator).send(amount), "Failed to send funds");

        project.totalAmountRaised = 0;

        // Reset the project to allow for a new round of funding
        project.isActive = true;
        project.isFunded = false;

        emit ProjectFunded(_projectId, msg.sender, amount);
    }

    function getProject(uint _projectId) public view returns (
        address payable creator,
        uint256 targetAmount,
        uint256 totalAmountRaised,
        uint256 deadline,
        bool isActive,
        bool isFunded
    ) {
        require(_projectId < projectCount, "Invalid project ID");

        Project storage project = projects[_projectId];

        return (
            project.creator,
            project.targetAmount,
            project.totalAmountRaised,
            project.deadline,
            project.isActive,
            project.isFunded
        );
    }

    function getProjectCount() public view returns (uint) {
        return projectCount;
    }
}
