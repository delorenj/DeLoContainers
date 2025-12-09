/*
    Flexisip, a flexible SIP proxy server with media capabilities.
    Copyright (C) 2010-2025 Belledonne Communications SARL, All rights reserved.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#pragma once

namespace flexisip {

/**
 * @brief Reason for call cancellation. Used to clarify the scenario that lead to the cancellation.
 */
enum class ForkStatus {
	// Branch canceled because the call has been accepted in another branch of the ForkContext.
	AcceptedElsewhere,
	// Branch canceled because the call has been declined in another branch.
	DeclinedElsewhere,
	// Branch canceled because the caller has canceled the call.
	Standard
};

} // namespace flexisip