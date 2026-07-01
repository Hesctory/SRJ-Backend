using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class User
{
    public int Id { get; set; }

    public string Names { get; set; } = null!;

    public string PaternalLastname { get; set; } = null!;

    public string MaternalLastname { get; set; } = null!;

    public string Email { get; set; } = null!;

    public string HashedPassword { get; set; } = null!;

    public string Phone { get; set; } = null!;

    public bool IsActive { get; set; }

    public virtual ICollection<EnrollmentDebt> EnrollmentDebts { get; set; } = new List<EnrollmentDebt>();

    public virtual ICollection<EnrollmentStateHistory> EnrollmentStateHistories { get; set; } = new List<EnrollmentStateHistory>();

    public virtual ICollection<LunchAssignment> LunchAssignments { get; set; } = new List<LunchAssignment>();

    public virtual ICollection<Payment> PaymentCreatedByNavigations { get; set; } = new List<Payment>();

    public virtual ICollection<Payment> PaymentVoidedByNavigations { get; set; } = new List<Payment>();

    public virtual ICollection<Role> Roles { get; set; } = new List<Role>();
}
