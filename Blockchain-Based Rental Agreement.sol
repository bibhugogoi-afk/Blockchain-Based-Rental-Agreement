// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Blockchain-Based Rental Agreement
 * @dev Smart contract for managing rental agreements on blockchain
 * @author Rental DApp Team
 */
contract Project {
    
    struct RentalAgreement {
        address landlord;
        address tenant;
        uint256 rentAmount;
        uint256 securityDeposit;
        uint256 startDate;
        uint256 endDate;
        bool isActive;
        bool depositPaid;
        uint256 lastRentPayment;
    }
    
    mapping(uint256 => RentalAgreement) public agreements;
    mapping(address => uint256[]) public landlordAgreements;
    mapping(address => uint256[]) public tenantAgreements;
    
    uint256 public agreementCounter;
    
    event AgreementCreated(
        uint256 indexed agreementId,
        address indexed landlord,
        address indexed tenant,
        uint256 rentAmount,
        uint256 securityDeposit
    );
    
    event RentPaid(
        uint256 indexed agreementId,
        address indexed tenant,
        uint256 amount,
        uint256 timestamp
    );
    
    event AgreementTerminated(
        uint256 indexed agreementId,
        address indexed terminatedBy,
        uint256 timestamp
    );
    
    modifier onlyLandlord(uint256 _agreementId) {
        require(agreements[_agreementId].landlord == msg.sender, "Only landlord can perform this action");
        _;
    }
    
    modifier onlyTenant(uint256 _agreementId) {
        require(agreements[_agreementId].tenant == msg.sender, "Only tenant can perform this action");
        _;
    }
    
    modifier agreementExists(uint256 _agreementId) {
        require(_agreementId > 0 && _agreementId <= agreementCounter, "Agreement does not exist");
        _;
    }
    
    modifier agreementActive(uint256 _agreementId) {
        require(agreements[_agreementId].isActive, "Agreement is not active");
        _;
    }
    
    /**
     * @dev Create a new rental agreement
     * @param _tenant Address of the tenant
     * @param _rentAmount Monthly rent amount in wei
     * @param _securityDeposit Security deposit amount in wei
     * @param _durationInDays Duration of the rental in days
     */
    function createAgreement(
        address _tenant,
        uint256 _rentAmount,
        uint256 _securityDeposit,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(_tenant != address(0), "Invalid tenant address");
        require(_tenant != msg.sender, "Landlord cannot be tenant");
        require(_rentAmount > 0, "Rent amount must be greater than 0");
        require(_securityDeposit > 0, "Security deposit must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        
        agreementCounter++;
        uint256 agreementId = agreementCounter;
        
        agreements[agreementId] = RentalAgreement({
            landlord: msg.sender,
            tenant: _tenant,
            rentAmount: _rentAmount,
            securityDeposit: _securityDeposit,
            startDate: block.timestamp,
            endDate: block.timestamp + (_durationInDays * 1 days),
            isActive: true,
            depositPaid: false,
            lastRentPayment: 0
        });
        
        landlordAgreements[msg.sender].push(agreementId);
        tenantAgreements[_tenant].push(agreementId);
        
        emit AgreementCreated(agreementId, msg.sender, _tenant, _rentAmount, _securityDeposit);
        
        return agreementId;
    }
    
    /**
     * @dev Pay rent for a specific agreement
     * @param _agreementId ID of the rental agreement
     */
    function payRent(uint256 _agreementId) 
        external 
        payable 
        agreementExists(_agreementId)
        agreementActive(_agreementId)
        onlyTenant(_agreementId)
    {
        RentalAgreement storage agreement = agreements[_agreementId];
        
        require(block.timestamp <= agreement.endDate, "Agreement has expired");
        require(msg.value == agreement.rentAmount, "Incorrect rent amount");
        
        // If security deposit not paid, require it with first rent payment
        if (!agreement.depositPaid) {
            require(msg.value == agreement.rentAmount + agreement.securityDeposit, 
                    "First payment must include rent + security deposit");
            agreement.depositPaid = true;
        }
        
        agreement.lastRentPayment = block.timestamp;
        
        // Transfer rent to landlord (keep security deposit in contract)
        uint256 rentToTransfer = agreement.depositPaid && msg.value > agreement.rentAmount ? 
                                agreement.rentAmount : msg.value;
        
        payable(agreement.landlord).transfer(rentToTransfer);
        
        emit RentPaid(_agreementId, msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Terminate rental agreement
     * @param _agreementId ID of the rental agreement
     */
    function terminateAgreement(uint256 _agreementId) 
        external 
        agreementExists(_agreementId)
        agreementActive(_agreementId)
    {
        RentalAgreement storage agreement = agreements[_agreementId];
        
        require(msg.sender == agreement.landlord || msg.sender == agreement.tenant, 
                "Only landlord or tenant can terminate");
        
        agreement.isActive = false;
        
        // Return security deposit to tenant if paid
        if (agreement.depositPaid) {
            payable(agreement.tenant).transfer(agreement.securityDeposit);
        }
        
        emit AgreementTerminated(_agreementId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Get agreement details
     * @param _agreementId ID of the rental agreement
     */
    function getAgreement(uint256 _agreementId) 
        external 
        view 
        agreementExists(_agreementId)
        returns (
            address landlord,
            address tenant,
            uint256 rentAmount,
            uint256 securityDeposit,
            uint256 startDate,
            uint256 endDate,
            bool isActive,
            bool depositPaid,
            uint256 lastRentPayment
        )
    {
        RentalAgreement memory agreement = agreements[_agreementId];
        return (
            agreement.landlord,
            agreement.tenant,
            agreement.rentAmount,
            agreement.securityDeposit,
            agreement.startDate,
            agreement.endDate,
            agreement.isActive,
            agreement.depositPaid,
            agreement.lastRentPayment
        );
    }
    
    /**
     * @dev Get agreements for a landlord
     * @param _landlord Address of the landlord
     */
    function getLandlordAgreements(address _landlord) external view returns (uint256[] memory) {
        return landlordAgreements[_landlord];
    }
    
    /**
     * @dev Get agreements for a tenant
     * @param _tenant Address of the tenant
     */
    function getTenantAgreements(address _tenant) external view returns (uint256[] memory) {
        return tenantAgreements[_tenant];
    }
    
    /**
     * @dev Check if rent is overdue
     * @param _agreementId ID of the rental agreement
     */
    function isRentOverdue(uint256 _agreementId) 
        external 
        view 
        agreementExists(_agreementId)
        returns (bool) 
    {
        RentalAgreement memory agreement = agreements[_agreementId];
        if (!agreement.isActive) return false;
        
        // Consider rent overdue if not paid for more than 30 days
        return (block.timestamp - agreement.lastRentPayment) > 30 days;
    }
}
