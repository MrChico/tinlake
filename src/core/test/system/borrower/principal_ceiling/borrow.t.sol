// Copyright (C) 2019 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.12;

import "../../system.sol";

contract BorrowTest is SystemTest {
        
    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_);
        createTestUsers();
    }
    
    function borrow(uint loanId, uint tokenId, uint amount) public {
        uint initialTotalBalance = shelf.balance();
        uint initialLoanBalance = shelf.balances(loanId);
        uint initialTotalDebt = pile.total();
        uint initialLoanDebt = pile.debt(loanId);
        uint initialCeiling = ceiling.ceiling(loanId);

        borrower.borrow(loanId, amount);
        assertPostCondition(loanId, tokenId, amount, initialTotalBalance, initialLoanBalance, initialTotalDebt, initialLoanDebt, initialCeiling);
    }

    function lockNFT(uint loanId) public {
        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.lock(loanId);
    }

    function assertPreCondition(uint loanId, uint tokenId, uint amount) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrowAmount <= ceiling
        assert(amount <= ceiling.ceiling(loanId));
    }

    function assertPostCondition(uint loanId, uint tokenId, uint amount, uint initialTotalBalance, uint initialLoanBalance, uint initialTotalDebt, uint initialLoanDebt, uint initialCeiling) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: borrower nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: totalBalance increase by borrow amount
        assertEq(shelf.balance(), safeAdd(initialTotalBalance, amount));
        // assert: loanBalance increase by borrow amount
        assertEq(shelf.balances(loanId), safeAdd(initialLoanBalance, amount));
        // assert: totalDebt increase by borrow amount
        assertEq(pile.total(), safeAdd(initialTotalDebt, amount));
        // assert: loanDebt increase by borrow amount
        assertEq(pile.debt(loanId), safeAdd(initialLoanDebt, amount));
        // assert: available borrow amount decreased
        assertEq(ceiling.ceiling(loanId), safeSub(initialCeiling, amount));
    }

    function testBorrow() public {
        uint ceiling = 100 ether;
        uint amount = ceiling;
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft for borrower
        lockNFT(loanId);
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        assertPreCondition(loanId, tokenId, amount);
        borrow(loanId, tokenId, amount);
    }

    function testPartialBorrow() public {
        uint ceiling = 200 ether;
        // borrow amount smaller then ceiling
        uint amount = safeDiv(ceiling ,2);
        (uint tokenId, ) = issueNFT(borrower_);
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        lockNFT(loanId);
        admin.setCeiling(loanId, ceiling);
        assertPreCondition(loanId, tokenId, amount);
        borrow(loanId, tokenId, amount);
    }

    function testFailBorrowNFTNotLocked() public {
        uint ceiling = 100 ether;
        uint amount = ceiling;
        (uint tokenId, ) = issueNFT(borrower_);
        uint loanId = borrower.issue(collateralNFT_, tokenId);  
        // do not lock nft
        admin.setCeiling(loanId, ceiling);
        borrow(loanId, tokenId, amount);
    }

    function testFailBorrowNotLoanOwner() public {
        uint ceiling = 100 ether;
        uint amount = ceiling;
        // issue nft for random user
        (uint tokenId, ) = issueNFT(randomUser_);
        // issue loan from random user
        uint loanId = randomUser.issue(collateralNFT_, tokenId);
        // lock nft for random user
        randomUser.lock(loanId); 
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        // borrower tries to borrow against loan
        borrow(loanId, tokenId, amount);
    }

    function testFailBorrowAmountTooHigh() public {
        uint ceiling = 100 ether;
        // borrow amount higher then ceiling
        uint amount = safeMul(ceiling, 2);
        (uint tokenId, ) = issueNFT(borrower_);
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        lockNFT(loanId);
        admin.setCeiling(loanId, ceiling);
        borrow(loanId, tokenId, amount);
    }

}