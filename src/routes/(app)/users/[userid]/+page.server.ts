import type { PageServerLoad, Actions } from './$types';
import { ldapClient } from '$lib/server/ldap';
import { fail, redirect } from '@sveltejs/kit';
import { base } from '$app/paths';

export const load: PageServerLoad = async ({ params }) => {
    const { userid } = params;
    
    try {
        const user = await ldapClient.getUser(userid);
        
        if (!user) {
            return {
                error: `User "${userid}" not found`,
                user: null
            };
        }
        
        return {
            error: null,
            user
        };
        
    } catch (error) {
        return {
            error: `Failed to load user: ${(error as Error).message}`,
            user: null
        };
    }
};

export const actions: Actions = {
    updateDetails: async ({ request, params }) => {
        const { userid } = params;
        
        try {
            const formData = await request.formData();
            const displayName = formData.get('displayName')?.toString() || '';
            const mail = formData.get('mail')?.toString() || '';
            const givenName = formData.get('givenName')?.toString() || '';
            const sn = formData.get('sn')?.toString() || '';
            
            // Validate email
            if (mail && !mail.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
                return fail(400, { error: 'Invalid email format' });
            }
            
            const success = await ldapClient.updateUser(userid, {
                displayName,
                mail,
                givenName,
                sn
            });
            
            if (!success) {
                return fail(500, { error: 'Failed to update user details' });
            }
            
            return { 
                success: true, 
                message: 'User details updated successfully',
                type: 'details'
            };
            
        } catch (error) {
            console.error('Error updating user details:', error);
            return fail(500, { error: `Failed to update user: ${(error as Error).message}` });
        }
    },
    
    changePassword: async ({ request, params }) => {
        const { userid } = params;
        
        try {
            const formData = await request.formData();
            const newPassword = formData.get('newPassword')?.toString();
            const repeatPassword = formData.get('repeatPassword')?.toString();
            
            if (!newPassword || !repeatPassword) {
                return fail(400, { error: 'Password fields are required' });
            }
            
            if (newPassword !== repeatPassword) {
                return fail(400, { error: 'Passwords do not match' });
            }
            
            // Validate password strength
            if (newPassword.length < 8) {
                return fail(400, { error: 'Password must be at least 8 characters long' });
            }
            
            const success = await ldapClient.changePassword(userid, newPassword);
            
            if (!success) {
                return fail(500, { error: 'Failed to change password' });
            }
            
            return { 
                success: true, 
                message: 'Password changed successfully',
                type: 'password'
            };
            
        } catch (error) {
            console.error('Error changing password:', error);
            return fail(500, { error: `Failed to change password: ${(error as Error).message}` });
        }
    },
    
    cancel: async ({ params }) => {
        throw redirect(303, `${base}/users`);
    }
};