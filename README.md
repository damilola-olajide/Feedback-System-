# Feedback System Smart Contract

A comprehensive Clarity smart contract for managing user feedback and ratings on the Stacks blockchain. This contract provides a robust system for collecting, managing, and analyzing user feedback with built-in rating calculations and administrative controls.

## Features

### Core Functionality
- **Submit Feedback**: Users can submit feedback with ratings (1-5 scale) and comments
- **Update Feedback**: Authors can modify their own feedback entries
- **Delete Feedback**: Authors and admins can remove feedback (soft delete)
- **Rating System**: Automatic calculation of average ratings for targets
- **User Tracking**: Track feedback count per user

### Administrative Features
- **Admin Management**: Contract owner can add/remove administrators
- **Permission Controls**: Role-based access for sensitive operations
- **Contract Statistics**: View total feedbacks and system stats

### Advanced Features
- **Batch Operations**: Retrieve multiple feedback entries at once
- **Target Rating Summaries**: Get aggregated rating data for any target
- **Input Validation**: Comprehensive validation to prevent invalid data
- **Soft Delete**: Maintains data integrity while marking entries as inactive

## Contract Structure

### Data Maps
- `feedbacks`: Stores individual feedback entries
- `user-feedback-count`: Tracks feedback count per user
- `target-ratings`: Aggregated rating data for targets
- `admins`: Admin user management

### Constants
- `CONTRACT_OWNER`: The deployer of the contract
- Error codes: `ERR_UNAUTHORIZED` (100), `ERR_NOT_FOUND` (101), `ERR_INVALID_RATING` (102), `ERR_ALREADY_EXISTS` (103), `ERR_INVALID_INPUT` (104), `ERR_PERMISSION_DENIED` (105)

## Public Functions

### User Functions

#### `submit-feedback`
Submit new feedback for a target.
```clarity
(submit-feedback (target-id (string-ascii 64)) (rating uint) (comment (string-utf8 500)))
